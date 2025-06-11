// SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
// SPDX-License-Identifier: LicenseRef-NvidiaProprietary
//
// NVIDIA CORPORATION, its affiliates and licensors retain all intellectual
// property and proprietary rights in and to this material, related
// documentation and any modifications thereto. Any use, reproduction,
// disclosure or distribution of this material and related documentation
// without an express license agreement from NVIDIA CORPORATION or
// its affiliates is strictly prohibited.

import Foundation

class TestHelper {
    static var configuratorAppModel: ConfiguratorAppModel?
    // Stores the environment variable for viewModel the test UI's views are using because it will not be the same object as
    // appModel.asset.viewModel if a test assigns a new AssetModel object to appModel.asset.
    static var configuratorViewModel: ConfiguratorViewModel?

    static var appModel: AppModel?
}
