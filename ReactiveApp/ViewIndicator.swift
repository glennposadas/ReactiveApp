//
//  ViewIndicator.swift
//  ReactiveApp
//
//  Created by SVYAT on 08.02.16.
//  Copyright © 2016 Svyatoslav Reshetnikov. All rights reserved.
//  Inspired by Krunoslav Zaher
//

import RxSwift
import RxCocoa

struct ViewToken<E> : ObservableConvertibleType, Disposable {
    private let _source: Observable<E>
    private let _dispose: AnonymousDisposable
    
    init(source: Observable<E>, disposeAction: () -> ()) {
        _source = source
        _dispose = AnonymousDisposable(disposeAction)
    }
    
    func dispose() {
        _dispose.dispose()
    }
    
    func asObservable() -> Observable<E> {
        return _source
    }
}

/**
 Enables monitoring of sequence computation.
 
 If there is at least one sequence computation in progress, `true` will be sent.
 When all activities complete `false` will be sent.
 */
class ViewIndicator : DriverConvertibleType {
    typealias E = Bool
    
    private let _lock = NSRecursiveLock()
    private let _variable = Variable(0)
    private let _loading: Driver<Bool>
    
    init() {
        _loading = _variable.asObservable()
            .map { $0 > 0 }
            .distinctUntilChanged()
            .asDriver { (error: ErrorType) -> Driver<Bool> in
                _ = fatalError("Loader can't fail")
                return Driver.empty()
            }
    }
    
    func trackView<O: ObservableConvertibleType>(source: O) -> Observable<O.E> {
        return Observable.using({ () -> ViewToken<O.E> in
            self.increment()
            return ViewToken(source: source.asObservable(), disposeAction: self.decrement)
            }) { t in
                return t.asObservable()
        }
    }
    
    private func increment() {
        _lock.lock()
        _variable.value = _variable.value + 1
        _lock.unlock()
    }
    
    private func decrement() {
        _lock.lock()
        _variable.value = _variable.value - 1
        _lock.unlock()
    }
    
    func asDriver() -> Driver<E> {
        return _loading
    }
}

extension ObservableConvertibleType {
    func trackView(viewIndicator: ViewIndicator) -> Observable<E> {
        return viewIndicator.trackView(self)
    }
}