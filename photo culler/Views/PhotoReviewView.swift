import SwiftUI

struct PhotoReviewView: View {
    @Bindable var viewModel: PhotoCullerViewModel
    @State private var showThumbnails = false

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.viewMode != .allPhotos {
                HStack(spacing: 6) {
                    switch viewModel.viewMode {
                    case .rejectedOnly:
                        Image(systemName: "magnifyingglass.circle.fill")
                        Text(viewModel.badPhotos.isEmpty
                            ? "Rejected Only — No rejected photos"
                            : "Rejected Only — \(viewModel.badPhotos.count) rejected photo(s)")
                            .font(.caption)
                    case .unratedOnly:
                        Image(systemName: "circle.dotted")
                        Text(viewModel.unratedPhotos.isEmpty
                            ? "Unrated Only — No unrated photos"
                            : "Unrated Only — \(viewModel.unratedPhotos.count) unrated photo(s)")
                            .font(.caption)
                    case .allPhotos:
                        EmptyView()
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(viewModel.viewMode == .rejectedOnly ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15))
                .foregroundStyle(viewModel.viewMode == .rejectedOnly ? AnyShapeStyle(.orange) : AnyShapeStyle(.blue))
            }

            ProgressBarView(
                ratedCount: viewModel.ratedCount,
                totalCount: viewModel.photoCount
            )

            if (viewModel.viewMode == .rejectedOnly && viewModel.badPhotos.isEmpty) ||
               (viewModel.viewMode == .unratedOnly && viewModel.unratedPhotos.isEmpty) {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    if viewModel.viewMode == .rejectedOnly {
                        Text("No Rejected Photos")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("All photos are rated Good or unrated.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("All Photos Rated")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("No unrated photos remaining.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
                totalCount: {
                    switch viewModel.viewMode {
                    case .allPhotos:    return viewModel.photoCount
                    case .rejectedOnly: return viewModel.badPhotos.count
                    case .unratedOnly:  return viewModel.unratedPhotos.count
                    }
                }(),
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
        .alert(viewModel.allRated ? "All Photos Rated" : "Confirm Deletion", isPresented: $viewModel.showCompletionDialog) {
            if viewModel.viewMode == .allPhotos || viewModel.viewMode == .unratedOnly {
                Button("Review Rejected Only") {
                    viewModel.enterReviewRejectsMode()
                }
            }
            Button("Delete \(viewModel.badCount) Bad Photo(s)", role: .destructive) {
                viewModel.confirmDeletion()
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelDeletion()
            }
        } message: {
            let unratedCount = viewModel.unratedPhotos.count
            if unratedCount > 0 {
                Text("\(viewModel.goodCount) good, \(viewModel.badCount) bad, \(unratedCount) unrated.\nDelete all bad photos and their associated files?")
            } else {
                Text("\(viewModel.goodCount) good, \(viewModel.badCount) bad.\nDelete all bad photos and their associated files?")
            }
        }
        .alert(viewModel.resultAlertTitle, isPresented: $viewModel.showDeletionResult) {
            if !viewModel.photos.isEmpty && !viewModel.hasJustRenamed {
                Button("Rename Photos…") {
                    viewModel.showRenameSheet = true
                }
            }
            Button(viewModel.hasJustRenamed ? "Done" : "Skip", role: .cancel) {}
        } message: {
            Text(viewModel.deletionResultMessage)
        }
        .sheet(isPresented: $viewModel.showRenameSheet) {
            RenameSheetView(viewModel: viewModel)
        }
        .onChange(of: viewModel.showDeletionResult) { _, isShowing in
            if !isShowing { viewModel.hasJustRenamed = false }
        }
    }
}
