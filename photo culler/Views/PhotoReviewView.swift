import SwiftUI

struct PhotoReviewView: View {
    @Bindable var viewModel: PhotoCullerViewModel
    @State private var showThumbnails = false

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isReviewRejectsMode {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass.circle.fill")
                    Text(viewModel.badPhotos.isEmpty
                        ? "Review Rejects — No rejected photos"
                        : "Review Rejects — \(viewModel.badPhotos.count) rejected photo(s)")
                        .font(.caption)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.15))
                .foregroundStyle(.orange)
            }

            ProgressBarView(
                ratedCount: viewModel.ratedCount,
                totalCount: viewModel.photoCount
            )

            if viewModel.isReviewRejectsMode && viewModel.badPhotos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("No Rejected Photos")
                        .font(.title2)
                        .fontWeight(.medium)
                    Text("All photos are rated Good or unrated.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                PhotoDisplayView(url: viewModel.displayedCurrentPhoto?.displayURL)
            }

            if let photo = viewModel.displayedCurrentPhoto {
                Text(photo.displayURL?.lastPathComponent ?? photo.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }

            Divider()

            BottomControlBar(
                currentIndex: viewModel.displayedCurrentIndex,
                totalCount: viewModel.isReviewRejectsMode ? viewModel.badPhotos.count : viewModel.photoCount,
                currentRating: viewModel.displayedCurrentPhoto?.rating,
                canGoPrevious: viewModel.displayedCanGoPrevious,
                canGoNext: viewModel.displayedCanGoNext,
                onPrevious: { viewModel.goToPreviousDisplayed() },
                onNext: { viewModel.goToNextDisplayed() },
                onRate: { rating in viewModel.rateCurrent(rating) }
            )
        }
        .overlay(alignment: .trailing) {
            // 热区（20pt）+ 缩略图面板共用一个 onContinuousHover，
            // 鼠标进入任意部分就显示，完全离开才隐藏
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: 20)
                    .contentShape(Rectangle())

                if showThumbnails {
                    Divider()
                    ThumbnailStripView(
                        photos: viewModel.displayedPhotos,
                        currentIndex: viewModel.displayedCurrentIndex,
                        onSelect: { index in viewModel.goToDisplayed(index: index) }
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    withAnimation(.easeInOut(duration: 0.2)) { showThumbnails = true }
                case .ended:
                    withAnimation(.easeInOut(duration: 0.25)) { showThumbnails = false }
                }
            }
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
