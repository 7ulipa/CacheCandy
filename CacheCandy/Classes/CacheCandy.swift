//
//  CacheCandy.swift
//  Pods
//
//  Created by DirGoTii on 26/02/2017.
//
//

import Foundation

public protocol Cachable {
    func cost() -> Int
    func writeTo(path: String)
    init?(path: String)
}

public protocol CacheKey: Hashable {
    func stringValue() -> String
}

class CacheNode<Key, Value> {
    let value: Value
    let key: Key
    init(_ value: Value, key: Key) {
        self.value = value
        self.key = key
    }
    weak var next: CacheNode<Key, Value>?
    weak var prev: CacheNode<Key, Value>?
}

public class Cache <Key: CacheKey, Value: Cachable> {
    var map: [Key: CacheNode<Key, Value>] = [:]
    var countLimit: Int = 0
    var totalCostLimit: Int = 0
    var cost: Int = 0
    var count: Int = 0
    var head: CacheNode<Key, Value>?
    var tail: CacheNode<Key, Value>?
    let workQueue = DispatchQueue(label: "com.cache.work-queue", qos: .default, attributes: [.concurrent])
    let ioQueue = DispatchQueue(label: "com.cache.io-queue", qos: .default, attributes: [.concurrent])
    let directory: String
    
    public init?(directory: String) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory) && isDirectory.boolValue else {
            return nil
        }
        
        self.directory = directory
    }
    
    func pathFor(key: Key) -> String {
        return (directory as NSString).appendingPathComponent(key.stringValue().addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key.stringValue())
    }
    
    public func cache(_ value: Value, for key: Key) {
        ioQueue.async(flags: .barrier) {
            self.removeFileCache(for: key)
            self.addFileCache(value, for: key)
        }
        workQueue.async(flags: .barrier) {
            self.removeMemoryCache(for: key)
            self.addMemoryCache(value, for: key)
        }
    }
    
    public func valueFor(key: Key, complete: @escaping (Value?) -> Void) {
        workQueue.async {
            if let node = self.map[key] {
                complete(node.value)
                if let prev = node.prev {
                    prev.next = node.next
                }
                node.next = self.head
                self.head = node
            } else {
                self.ioQueue.async {
                    let path = self.pathFor(key: key)
                    if FileManager.default.fileExists(atPath: path) {
                        if let value = Value(path: path) {
                            complete(value)
                            self.workQueue.async(flags: .barrier) {
                                self.addMemoryCache(value, for: key)
                            }
                        } else {
                            complete(nil)
                        }
                    } else {
                        complete(nil)
                    }
                }
            }
        }
    }
    
    public func valueFor(key: Key) -> Value? {
        var node: CacheNode<Key, Value>?
        workQueue.sync {
            node = map[key]
        }
        if let result = node {
            workQueue.async(flags: .barrier) {
                if let prev = result.prev {
                    prev.next = result.next
                    result.next = self.head
                    self.head = result
                }
            }
            return result.value
        }
        
        var value: Value?
        ioQueue.sync {
            let path = self.pathFor(key: key)
            if FileManager.default.fileExists(atPath: path) {
                value = Value(path: path)
            }
        }
        if let value = value {
            workQueue.async(flags: .barrier) {
                self.addMemoryCache(value, for: key)
            }
        }
        
        return value
    }
    
    private func addMemoryCache(_ value: Value, for key: Key) {
        let node = CacheNode(value, key: key)
        map[key] = node
        node.next = head
        head = node
        if tail == nil {
            tail = node
        }
        
        if totalCostLimit > 0 {
            while cost > totalCostLimit {
                if let tail = tail {
                    map.removeValue(forKey: tail.key)
                }
                tail = tail?.prev
                tail?.next = nil
            }
        }
    }
    
    private func addFileCache(_ value: Value, for key: Key) {
        value.writeTo(path: pathFor(key: key))
    }
    
    private func removeMemoryCache(for key: Key) {
        if let value = map[key]?.value {
            map.removeValue(forKey: key)
            cost = cost - value.cost()
        }
    }
    
    private func removeFileCache(for key: Key) {
        let path = self.pathFor(key: key)
        if FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.removeItem(atPath: path)
        }
    }
}


