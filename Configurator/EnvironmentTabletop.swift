// SPDX-FileCopyrightText: Copyright (c) 2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
// SPDX-License-Identifier: LicenseRef-NvidiaProprietary
//
// NVIDIA CORPORATION, its affiliates and licensors retain all intellectual
// property and proprietary rights in and to this material, related
// documentation and any modifications thereto. Any use, reproduction,
// disclosure or distribution of this material and related documentation
// without an express license agreement from NVIDIA CORPORATION or
// its affiliates is strictly prohibited.

import SwiftUI
import UIKit
import CloudXRKit

struct EnvironmentTabletop: View {
    @Environment(AppModel.self) var appModel
    @Environment(ViewModel.self) var viewModel
    @Binding var section: ViewSelector.Section

    let lightingColumns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    if let sessionEntity = viewModel.sessionEntity {
                        sessionEntity.scale = .one
                    }
                } label: {
                    Image(systemName: "scale.3d")
                    Text("Reset Scale")
                }
                .environmentButton()
                Spacer()
                Button {
                    // this button is hidden for now
                } label: {
                    Image(systemName: "scale.3d")
                    Text("Place Purse")
                }
                .environmentButton()
                .hidden()
                Spacer()
            }
            .environmentGroup()
        }
        .padding(.all)
    }
}
