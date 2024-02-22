//
//  Invalidating+Extensions.swift
//
//
//  Created by Suyash Srijan on 29/06/2021.
//

import Foundation

extension ViewInvalidating {
    public typealias Tuple = Invalidations.Tuple

    public init<InvalidationType1: InvalidatingViewProtocol, InvalidationType2: InvalidatingViewProtocol>(wrappedValue: Value, _ invalidation1: InvalidationType1, _ invalidation2: InvalidationType2) where InvalidationType == Tuple<InvalidationType1, InvalidationType2> {
        self.init(wrappedValue: wrappedValue, .init(invalidation1: invalidation1, invalidation2: invalidation2))
    }

    public init<InvalidationType1: InvalidatingViewProtocol, InvalidationType2: InvalidatingViewProtocol, InvalidationType3: InvalidatingViewProtocol>(wrappedValue: Value, _ invalidation1: InvalidationType1, _ invalidation2: InvalidationType2, _ invalidation3: InvalidationType3) where InvalidationType == Tuple<Tuple<InvalidationType1, InvalidationType2>, InvalidationType3> {
        self.init(wrappedValue: wrappedValue, .init(invalidation1: .init(invalidation1: invalidation1, invalidation2: invalidation2), invalidation2: invalidation3))
    }

    public init<InvalidationType1: InvalidatingViewProtocol, InvalidationType2: InvalidatingViewProtocol, InvalidationType3: InvalidatingViewProtocol, InvalidationType4: InvalidatingViewProtocol>(wrappedValue: Value, _ invalidation1: InvalidationType1, _ invalidation2: InvalidationType2, _ invalidation3: InvalidationType3, _ invalidation4: InvalidationType4) where InvalidationType == Tuple<Tuple<InvalidationType1, InvalidationType2>, Tuple<InvalidationType3, InvalidationType4>> {
        self.init(wrappedValue: wrappedValue, .init(invalidation1: .init(invalidation1: invalidation1, invalidation2: invalidation2), invalidation2: .init(invalidation1: invalidation3, invalidation2: invalidation4)))
    }

    public init<InvalidationType1: InvalidatingViewProtocol, InvalidationType2: InvalidatingViewProtocol, InvalidationType3: InvalidatingViewProtocol, InvalidationType4: InvalidatingViewProtocol, InvalidationType5: InvalidatingViewProtocol>(wrappedValue: Value, _ invalidation1: InvalidationType1, _ invalidation2: InvalidationType2, _ invalidation3: InvalidationType3, _ invalidation4: InvalidationType4, _ invalidation5: InvalidationType5) where InvalidationType == Tuple<Tuple<Tuple<InvalidationType1, InvalidationType2>, Tuple<InvalidationType3, InvalidationType4>>, InvalidationType5> {
        self.init(wrappedValue: wrappedValue, .init(invalidation1: .init(invalidation1: .init(invalidation1: invalidation1, invalidation2: invalidation2), invalidation2: .init(invalidation1: invalidation3, invalidation2: invalidation4)), invalidation2: invalidation5))
    }

    public init<InvalidationType1: InvalidatingViewProtocol, InvalidationType2: InvalidatingViewProtocol, InvalidationType3: InvalidatingViewProtocol, InvalidationType4: InvalidatingViewProtocol, InvalidationType5: InvalidatingViewProtocol, InvalidationType6: InvalidatingViewProtocol>(wrappedValue: Value, _ invalidation1: InvalidationType1, _ invalidation2: InvalidationType2, _ invalidation3: InvalidationType3, _ invalidation4: InvalidationType4, _ invalidation5: InvalidationType5, _ invalidation6: InvalidationType6) where InvalidationType == Tuple<Tuple<Tuple<InvalidationType1, InvalidationType2>, Tuple<InvalidationType3, InvalidationType4>>, Tuple<InvalidationType5, InvalidationType6>> {
        self.init(wrappedValue: wrappedValue, .init(invalidation1: .init(invalidation1: .init(invalidation1: invalidation1, invalidation2: invalidation2), invalidation2: .init(invalidation1: invalidation3, invalidation2: invalidation4)), invalidation2: .init(invalidation1: invalidation5, invalidation2: invalidation6)))
    }

    public init<InvalidationType1: InvalidatingViewProtocol, InvalidationType2: InvalidatingViewProtocol, InvalidationType3: InvalidatingViewProtocol, InvalidationType4: InvalidatingViewProtocol, InvalidationType5: InvalidatingViewProtocol, InvalidationType6: InvalidatingViewProtocol, InvalidationType7: InvalidatingViewProtocol>(wrappedValue: Value, _ invalidation1: InvalidationType1, _ invalidation2: InvalidationType2, _ invalidation3: InvalidationType3, _ invalidation4: InvalidationType4, _ invalidation5: InvalidationType5, _ invalidation6: InvalidationType6, _ invalidation7: InvalidationType7) where InvalidationType == Tuple<Tuple<Tuple<InvalidationType1, InvalidationType2>, Tuple<InvalidationType3, InvalidationType4>>, Tuple<Tuple<InvalidationType5, InvalidationType6>, InvalidationType7>> {
        self.init(wrappedValue: wrappedValue, .init(invalidation1: .init(invalidation1: .init(invalidation1: invalidation1, invalidation2: invalidation2), invalidation2: .init(invalidation1: invalidation3, invalidation2: invalidation4)), invalidation2: .init(invalidation1: .init(invalidation1: invalidation5, invalidation2: invalidation6), invalidation2: invalidation7)))
    }

    public init<InvalidationType1: InvalidatingViewProtocol, InvalidationType2: InvalidatingViewProtocol, InvalidationType3: InvalidatingViewProtocol, InvalidationType4: InvalidatingViewProtocol, InvalidationType5: InvalidatingViewProtocol, InvalidationType6: InvalidatingViewProtocol, InvalidationType7: InvalidatingViewProtocol, InvalidationType8: InvalidatingViewProtocol>(wrappedValue: Value, _ invalidation1: InvalidationType1, _ invalidation2: InvalidationType2, _ invalidation3: InvalidationType3, _ invalidation4: InvalidationType4, _ invalidation5: InvalidationType5, _ invalidation6: InvalidationType6, _ invalidation7: InvalidationType7, _ invalidation8: InvalidationType8) where InvalidationType == Tuple<Tuple<Tuple<InvalidationType1, InvalidationType2>, Tuple<InvalidationType3, InvalidationType4>>, Tuple<Tuple<InvalidationType5, InvalidationType6>, Tuple<InvalidationType7, InvalidationType8>>> {
        self.init(wrappedValue: wrappedValue, .init(invalidation1: .init(invalidation1: .init(invalidation1: invalidation1, invalidation2: invalidation2), invalidation2: .init(invalidation1: invalidation3, invalidation2: invalidation4)), invalidation2: .init(invalidation1: .init(invalidation1: invalidation5, invalidation2: invalidation6), invalidation2: .init(invalidation1: invalidation7, invalidation2: invalidation8))))
    }

    public init<InvalidationType1: InvalidatingViewProtocol, InvalidationType2: InvalidatingViewProtocol, InvalidationType3: InvalidatingViewProtocol, InvalidationType4: InvalidatingViewProtocol, InvalidationType5: InvalidatingViewProtocol, InvalidationType6: InvalidatingViewProtocol, InvalidationType7: InvalidatingViewProtocol, InvalidationType8: InvalidatingViewProtocol, InvalidationType9: InvalidatingViewProtocol>(wrappedValue: Value, _ invalidation1: InvalidationType1, _ invalidation2: InvalidationType2, _ invalidation3: InvalidationType3, _ invalidation4: InvalidationType4, _ invalidation5: InvalidationType5, _ invalidation6: InvalidationType6, _ invalidation7: InvalidationType7, _ invalidation8: InvalidationType8, _ invalidation9: InvalidationType9) where InvalidationType == Tuple<Tuple<Tuple<Tuple<InvalidationType1, InvalidationType2>, Tuple<InvalidationType3, InvalidationType4>>, Tuple<Tuple<InvalidationType5, InvalidationType6>, Tuple<InvalidationType7, InvalidationType8>>>, InvalidationType9> {
        self.init(wrappedValue: wrappedValue, .init(invalidation1: .init(invalidation1: .init(invalidation1: .init(invalidation1: invalidation1, invalidation2: invalidation2), invalidation2: .init(invalidation1: invalidation3, invalidation2: invalidation4)), invalidation2: .init(invalidation1: .init(invalidation1: invalidation5, invalidation2: invalidation6), invalidation2: .init(invalidation1: invalidation7, invalidation2: invalidation8))), invalidation2: invalidation9))
    }

    public init<InvalidationType1: InvalidatingViewProtocol, InvalidationType2: InvalidatingViewProtocol, InvalidationType3: InvalidatingViewProtocol, InvalidationType4: InvalidatingViewProtocol, InvalidationType5: InvalidatingViewProtocol, InvalidationType6: InvalidatingViewProtocol, InvalidationType7: InvalidatingViewProtocol, InvalidationType8: InvalidatingViewProtocol, InvalidationType9: InvalidatingViewProtocol, InvalidationType10: InvalidatingViewProtocol>(wrappedValue: Value, _ invalidation1: InvalidationType1, _ invalidation2: InvalidationType2, _ invalidation3: InvalidationType3, _ invalidation4: InvalidationType4, _ invalidation5: InvalidationType5, _ invalidation6: InvalidationType6, _ invalidation7: InvalidationType7, _ invalidation8: InvalidationType8, _ invalidation9: InvalidationType9, _ invalidation10: InvalidationType10) where InvalidationType == Tuple<Tuple<Tuple<Tuple<InvalidationType1, InvalidationType2>, Tuple<InvalidationType3, InvalidationType4>>, Tuple<Tuple<InvalidationType5, InvalidationType6>, Tuple<InvalidationType7, InvalidationType8>>>, Tuple<InvalidationType9, InvalidationType10>> {
        self.init(wrappedValue: wrappedValue, .init(invalidation1: .init(invalidation1: .init(invalidation1: .init(invalidation1: invalidation1, invalidation2: invalidation2), invalidation2: .init(invalidation1: invalidation3, invalidation2: invalidation4)), invalidation2: .init(invalidation1: .init(invalidation1: invalidation5, invalidation2: invalidation6), invalidation2: .init(invalidation1: invalidation7, invalidation2: invalidation8))), invalidation2: .init(invalidation1: invalidation9, invalidation2: invalidation10)))
    }
}
