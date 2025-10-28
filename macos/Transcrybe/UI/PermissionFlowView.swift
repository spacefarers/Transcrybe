//
//  PermissionFlowView.swift
//  Transcrybe
//
//  View shown during permission request flow
//

import SwiftUI

struct PermissionFlowView: View {
    @ObservedObject var permissionManager: PermissionManager

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("Verifying Permissions")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Checking permissions required to use Transcrybe...")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                PermissionStepIndicator(
                    stepNumber: 1,
                    title: "Microphone Access",
                    isActive: permissionManager.currentPermissionStep == 0
                )

                PermissionStepIndicator(
                    stepNumber: 2,
                    title: "Accessibility",
                    isActive: permissionManager.currentPermissionStep == 1
                )
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 8) {
                Text("Why we need these permissions:")
                    .fontWeight(.semibold)
                    .font(.caption)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.blue)
                        Text("Microphone - To record your audio")
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "accessibility.fill")
                            .foregroundStyle(.blue)
                        Text("Accessibility - To detect Function key & insert text")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)

            Text("Follow the system prompts to grant each permission.\nIf you deny any permission, the app will exit.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(32)
        .frame(minWidth: 400, minHeight: 500)
    }
}

struct PermissionStepIndicator: View {
    let stepNumber: Int
    let title: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isActive ? Color.blue : Color.gray.opacity(0.3))
                .frame(width: 32, height: 32)
                .overlay(
                    Text("\(stepNumber)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                )

            Text(title)
                .fontWeight(isActive ? .semibold : .regular)
                .foregroundStyle(isActive ? .primary : .secondary)

            Spacer()

            if isActive {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(12)
        .background(isActive ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
}

#Preview {
    PermissionFlowView(permissionManager: PermissionManager())
}
