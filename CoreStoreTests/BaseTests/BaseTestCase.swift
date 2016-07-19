//
//  BaseTestCase.swift
//  CoreStore
//
//  Copyright © 2016 John Rommel Estropia
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import XCTest

@testable
import CoreStore


// MARK: - BaseTestCase

class BaseTestCase: XCTestCase {
    
    // MARK: Internal
    
    @nonobjc
    func prepareStack<T>(_ configurations: [String?] = [nil], @noescape _ closure: (dataStack: DataStack) -> T) -> T {
        
        let stack = DataStack(
            modelName: "Model",
            bundle: Bundle(forClass: self.dynamicType)
        )
        do {
            
            try configurations.forEach {
                
                try stack.addStorageAndWait(
                    SQLiteStore(
                        fileURL: SQLiteStore.defaultRootDirectory
                            .URLByAppendingPathComponent(UUID().UUIDString)
                            .URLByAppendingPathComponent("\(self.dynamicType)_\(($0 ?? "-null-")).sqlite"),
                        configuration: $0,
                        localStorageOptions: .recreateStoreOnModelMismatch
                    )
                )
            }
        }
        catch let error as NSError {
            
            XCTFail(error.coreStoreDumpString)
        }
        return closure(dataStack: stack)
    }
    
    @nonobjc
    func expectLogger<T>(_ expectations: [TestLogger.Expectation], @noescape closure: () -> T) -> T {
        
        CoreStore.logger = TestLogger(self.prepareLoggerExpectations(expectations))
        defer {
            
            self.checkExpectationsImmediately()
            CoreStore.logger = TestLogger([:])
        }
        return closure()
    }
    
    @nonobjc
    func expectLogger(_ expectations: [TestLogger.Expectation: XCTestExpectation]) {
        
        CoreStore.logger = TestLogger(expectations)
    }
    
    @nonobjc
    func prepareLoggerExpectations(_ expectations: [TestLogger.Expectation]) -> [TestLogger.Expectation: XCTestExpectation] {
        
        var testExpectations: [TestLogger.Expectation: XCTestExpectation] = [:]
        for expectation in expectations {
            
            testExpectations[expectation] = self.expectation(withDescription: "Logger Expectation: \(expectation)")
        }
        return testExpectations
    }
    
    @nonobjc
    func checkExpectationsImmediately() {
        
        self.waitForExpectations(withTimeout: 0, handler: nil)
    }
    
    @nonobjc
    func waitAndCheckExpectations() {
        
        self.waitForExpectations(withTimeout: 10, handler: nil)
    }
    
    // MARK: XCTestCase
    
    override func setUp() {
        
        super.setUp()
        self.deleteStores()
        CoreStore.logger = TestLogger([:])
    }
    
    override func tearDown() {
        
        CoreStore.logger = DefaultLogger()
        self.deleteStores()
        super.tearDown()
    }
    
    
    // MARK: Private
    
    private func deleteStores() {
        
        _ = try? FileManager.defaultManager().removeItemAtURL(SQLiteStore.defaultRootDirectory)
    }
}


// MARK: - TestLogger

class TestLogger: CoreStoreLogger {
    
    enum Expectation {
        
        case logWarning
        case logFatal
        case logError
        case assertionFailure
        case fatalError
    }
    
    init(_ expectations: [Expectation: XCTestExpectation]) {
        
        self.expectations = expectations
    }
    
    
    // MARK: CoreStoreLogger
    
    func log(_ level: LogLevel, message: String, fileName: StaticString, lineNumber: Int, functionName: StaticString) {
        
        switch level {
            
        case .warning:  self.fulfill(.logWarning)
        case .fatal:    self.fulfill(.logFatal)
        default:        break
        }
    }
    
    func log(_ error: CoreStoreError, message: String, fileName: StaticString, lineNumber: Int, functionName: StaticString) {
        
        self.fulfill(.logError)
    }
    
    func assert(@autoclosure _ condition: () -> Bool, @autoclosure message: () -> String, fileName: StaticString, lineNumber: Int, functionName: StaticString) {
        
        if condition() {
            
            return
        }
        self.fulfill(.assertionFailure)
    }
    
    func abort(_ message: String, fileName: StaticString, lineNumber: Int, functionName: StaticString) {
        
        self.fulfill(.fatalError)
    }
    
    
    // MARK: Private
    
    private var expectations: [Expectation: XCTestExpectation]
    
    private func fulfill(_ expectation: Expectation) {
        
        if let instance = self.expectations[expectation] {
            
            instance.fulfill()
            self.expectations[expectation] = nil
        }
        else {
            
            XCTFail("Unexpected Logger Action: \(expectation)")
        }
    }
}
