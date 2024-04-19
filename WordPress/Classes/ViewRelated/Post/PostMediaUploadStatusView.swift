import Foundation
import SwiftUI

/// Displays upload progress for the media for the given post.
struct PostMediaUploadStatusView: View {
    @ObservedObject var viewModel: PostMediaUploadViewModel
    let onCloseTapped: () -> Void

    var body: some View {
        List {
            ForEach(viewModel.uploads) {
                MediaUploadStatusView(viewModel: $0)
            }
        }
        .listStyle(.plain)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(Strings.close, action: onCloseTapped)
            }
            ToolbarItem(placement: .principal) {
                PostMediaUploadTitleView(viewModel: viewModel)
            }
        }
        .navigationTitle(Strings.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PostMediaUploadTitleView: View {
    @ObservedObject var viewModel: PostMediaUploadViewModel

    var body: some View {
        if viewModel.isCompleted {
            Text(Strings.title)
                .font(.headline)
        } else {
            VStack(spacing: 6) {
                Text(Strings.titleUploading)
                    .font(.headline)
                ProgressView(value: viewModel.fractionCompleted)
                    .progressViewStyle(.linear)
                    .tint(.secondary)
                    .background()
            }
            .fixedSize()
        }
    }
}

private struct MediaUploadStatusView: View {
    @ObservedObject var viewModel: MediaUploadViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            MediaThubmnailImageView(image: viewModel.thumbnail)
                .aspectRatio(viewModel.thumbnailAspectRatio, contentMode: .fit)
                .frame(maxHeight: viewModel.thumbnailMaxHeight)
                .clipped()
                .frame(width: 40, height: 40)

            VStack(alignment: .leading) {
                Text(viewModel.title)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(viewModel.details)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            switch viewModel.state {
            case .uploaded:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.secondary.opacity(0.5))
            case .uploading:
                MediaUploadProgressView(progress: viewModel.fractionCompleted)
            }
        }
        .task {
            await viewModel.loadThumbnail()
        }
    }
}

private struct MediaUploadProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    Color.secondary.opacity(0.25),
                    lineWidth: 3
                )
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color(uiColor: .brand), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut, value: progress)
        }
        .frame(width: 16, height: 16)
    }
}

private struct MediaThubmnailImageView: View {
    let image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .cornerRadius(6)
            } else {
                Color(uiColor: .secondarySystemBackground)
                    .cornerRadius(6)
            }
        }
    }
}

private enum Strings {
    static let title = NSLocalizedString("postMediaUploadStatusView.title", value: "Media Uploads", comment: "Title for post media upload status view")
    static let titleUploading = NSLocalizedString("postMediaUploadStatusView.titleUploading", value: "Uploading media", comment: "Title for a footer view in the post media upload status view")
    static let close = NSLocalizedString("postMediaUploadStatusView.close", value: "Close", comment: "Close button in postMediaUploadStatusView")
}
