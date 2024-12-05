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
import CloudXRKit

struct CameraSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) var appModel

    var body: some View {
        header

        Spacer()
            .frame(width: 1, height: UIConstants.margin)

        List {
            Section(header: Text("Exterior")) {
                ForEach(ExteriorCamera.allCases, id: \.rawValue) { cam in
                    cameraButton(cam, reset: false)
                }
            }
        }

        Spacer()
    }

    // Header of the camera panel
    var header: some View {
        HStack {
            // "X" button
            Button {
                dismiss()
            } label: {
                VStack {
                    Image(systemName: "xmark")
                }
                .padding(.vertical, 20)
            }

            Spacer()

            Text("Camera")
                .font(.title)

            Spacer()
        }
    }

    func cameraButton(_ camera: any CameraProtocol, reset: Bool) -> some View {
        Button {
            appModel.session.sendServerMessage(encodeJSON(camera.encodable))
            dismiss()
        } label: {
            Text(camera.description)
                .font(.callout)
        }
    }
}

#Preview {
    @Previewable @State var session = CloudXRSession(config: Config())
    return VStack {
        CameraSheet()
    }
    .environment(session)
    .ornamentStyle
}
