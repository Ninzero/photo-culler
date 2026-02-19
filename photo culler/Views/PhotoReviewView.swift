import SwiftUI

struct PhotoReviewView: View {
    @Bindable var viewModel: PhotoCullerViewModel
    @State private var showThumbnails = false

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
                        photos: viewModel.photos,
                        currentIndex: viewModel.currentIndex,
                        onSelect: { index in viewModel.goTo(index: index) }
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
