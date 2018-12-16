//
//  StateMachine.swift
//  Stateful
//
//  Created by Alberto De Bortoli on 16/12/2018.
//

import Foundation

final public class StateMachine {
    
    public var enableLogging: Bool = false
    public var currentState: String {
        return {
            workingQueue.sync {
                return internalCurrentState
            }
        }()
    }
    
    private var internalCurrentState: String
    private var transitionsByEvent: [String : [Transition]] = [:]
    
    private let lockQueue: DispatchQueue
    private let workingQueue: DispatchQueue
    private let callbackQueue: DispatchQueue
    
    public init(initialState: String, callbackQueue: DispatchQueue? = nil) {
        self.internalCurrentState = initialState
        self.lockQueue = DispatchQueue(label: "com.albertodebortoli.statemachine.queue.lock")
        self.workingQueue = DispatchQueue(label: "com.albertodebortoli.statemachine.queue.working")
        self.callbackQueue = callbackQueue ?? DispatchQueue.main
    }
    
    public func add(transition: Transition) {
        lockQueue.sync {
            let transitions = self.transitionsByEvent[transition.event]
            if transitions == nil {
                self.transitionsByEvent[transition.event] = [transition]
            } else {
                self.transitionsByEvent[transition.event]?.append(transition)
            }
        }
    }
    
    public func process(event: String, callback: TransitionBlock? = nil) {
        var transitions: [Transition]?
        lockQueue.sync {
            transitions = self.transitionsByEvent[event]
        }
        
        workingQueue.async {
            let performableTransitions = transitions?.filter { return $0.source == self.internalCurrentState } ?? []
            
            if performableTransitions.count == 0 {
                self.callbackQueue.async {
                    callback?(.failure)
                }
                return
            }
            
            for transition in performableTransitions {
                self.log(message: "[Stateful 🦜]: Processing event '\(event)' from '\(self.internalCurrentState)'")
                self.callbackQueue.async {
                    transition.executePreBlock()
                }
                
                self.log(message: "[Stateful 🦜]: Processed pre condition for event '\(event)' from '\(transition.source)' to '\(transition.destination)'")
                
                let previousState = self.internalCurrentState
                self.internalCurrentState = transition.destination
                
                self.log(message: "[Stateful 🦜]: Processed state change from '\(previousState)' to '\(transition.destination)'")
                self.callbackQueue.async {
                    transition.executePostBlock()
                }
                
                self.log(message: "[Stateful 🦜]: Processed post condition for event '\(event)' from '\(transition.source)' to '\(transition.destination)'")
                
                self.callbackQueue.async {
                    callback?(.success)
                }
            }
        }
    }
    
    private func log(message: String) {
        if self.enableLogging {
            print(message)
        }
    }
}
