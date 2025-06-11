// SPDX-FileCopyrightText: Copyright (c) 2023-2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
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
import ARKit

struct StarRatingView: View {

    @State private var selectedReason = FeedbackReason.none
    @State private var rating: Int = 0
    @State private var ratingSelected = false

    @Environment(AppModel.self) var appModel
    var body: some View {
        VStack {
            Text("Rate your experience")
                .font(.title)
                .padding()
            HStack {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .foregroundColor(star <= rating ? .yellow : .gray)
                        .onTapGesture {
                            rating = star
                            ratingSelected = true
                            // 5-star rating does not require a reason
                            if rating == 5 {
                                selectedReason = FeedbackReason.none
                            }
                        }
                }
            }
            .font(.largeTitle)
            .padding()

            if ratingSelected && rating < 5 {
                Picker("Select a reason", selection: $selectedReason) {
                    ForEach(FeedbackReason.allCases, id: \.self) {
                        if $0 == .none {
                            Text("Please select a reason")
                        } else {
                            Text($0.rawValue)
                        }
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding()
            }

            Button("Send feedback") {
                appModel.disableFeedback = true
                if selectedReason == FeedbackReason.none {
                    appModel.ratingText = "Score: \(rating)"
                } else {
                    appModel.ratingText = "Score: \(rating), Reason: \(selectedReason.rawValue)"
                }
                appModel.isRatingViewPresented = false
                appModel.session?.sendUserFeedback(rating: rating, selectedReason: selectedReason)
            }
            .disabled(rating==0)
            .padding()
        }
    }
}
