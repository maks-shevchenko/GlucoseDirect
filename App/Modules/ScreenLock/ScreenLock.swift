//
//  ScreenLock.swift
//  GlucoseDirect
//

import Combine
import Foundation
import UIKit

func screenLockMiddleware() -> Middleware<DirectState, DirectAction> {
    return { _, action, _ in
        switch action {
        case let .setPreventScreenLock(enabled: enabled):
            UIApplication.shared.isIdleTimerDisabled = enabled

        default:
            break
        }

        return Empty().eraseToAnyPublisher()
    }
}
