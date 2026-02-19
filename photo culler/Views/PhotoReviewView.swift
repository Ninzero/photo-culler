import SwiftUI

struct PhotoReviewView: View {
    @Bindable var viewModel: PhotoCullerViewModel

    var body: some View {
        HStack(spacing: 0) {
            // 主体区域
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

            Divider()

            // 右侧缩略图列
            ThumbnailStripView(
                photos: viewModel.photos,
                currentIndex: viewModel.currentIndex,
                onSelect: { index in viewModel.goTo(index: index) }
            )
        }
        .alert("All Photos Rated", isPresented: $viewModel.showCompletionDialog) {
            Button("Delete \(viewModel.badCount) Bad Photo(s)", role: .destructive) {
                viewModel.confirmDeletion()
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelDeletion()
            }
        } message: {
            Text("\(viewModel.goodCount) good, \(viewModel.badCount) bad.\nDelete all bad photos and their associated files?")
        }
        .alert("Deletion Complete", isPresented: $viewModel.showDeletionResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.deletionResultMessage)
        }
    }
}
