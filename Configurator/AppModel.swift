// SPDX-FileCopyrightText: Copyright (c) 2023-2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
// SPDX-License-Identifier: LicenseRef-NvidiaProprietary
//
// NVIDIA CORPORATION, its affiliates and licensors retain all intellectual
// property and proprietary rights in and to this material, related
// documentation and any modifications thereto. Any use, reproduction,
// disclosure or distribution of this material and related documentation
// without an express license agreement from NVIDIA CORPORATION or
// its affiliates is strictly prohibited.
//

import Foundation
import CloudXRKit

@Observable
public class AppModel {
    public var session: Session = CloudXRSession(
        config: CloudXRKit.Config()
    )

    // State manager timeout: 2 mins (8 * 15 seconds)
    public var stateManager = OmniverseStateManager(resyncDuration: 15.0, resyncCountTimeout: 8)

    init() {
        stateManager.session = session
    }
}
