import SwiftUI

struct PhotoReviewView: View {
    @Bindable var viewModel: PhotoCullerViewModel

    var body: some View {
        VStack(spacing: 0) {
            ProgressBarView(
                ratedCount: viewModel.ratedCount,
                totalCount: viewModel.photoCount
            )

            PhotoDisplayView(url: viewModel.currentPhoto?.displayURL)

            if let photo = viewModel.currentPhoto {
                Text(photo.displayURL?.lastPathComponent ?? photo.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }

            Divider()

            BottomControlBar(
                currentIndex: viewModel.currentIndex,
                totalCount: viewModel.photoCount,
                currentRating: viewModel.currentPhoto?.rating,
                canGoPrevious: viewModel.canGoPrevious,
                canGoNext: viewModel.canGoNext,
                onPrevious: { viewModel.goToPrevious() },
                onNext: { viewModel.goToNext() },
                onRate: { rating in viewModel.rateCurrent(rating) }
            )
        }
    }
}
