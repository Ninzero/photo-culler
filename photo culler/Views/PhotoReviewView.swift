import SwiftUI

struct PhotoReviewView: View {
    @Bindable var viewModel: PhotoCullerViewModel
    @State private var showThumbnails = false
    @State private var showExif = false

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
                    case .prizedOnly:
                        Image(systemName: "star.fill")
                        Text(viewModel.goodPhotos.isEmpty
                            ? "Prized Only — No prized photos"
                            : "Prized Only — \(viewModel.goodPhotos.count) prized photo(s)")
                            .font(.caption)
                    case .allPhotos:
                        EmptyView()
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background({
                    switch viewModel.viewMode {
                    case .rejectedOnly: return Color.orange.opacity(0.15)
                    case .prizedOnly:   return Color.green.opacity(0.15)
                    default:            return Color.blue.opacity(0.15)
                    }
                }())
                .foregroundStyle({
                    switch viewModel.viewMode {
                    case .rejectedOnly: return AnyShapeStyle(.orange)
                    case .prizedOnly:   return AnyShapeStyle(.green)
                    default:            return AnyShapeStyle(.blue)
                    }
                }())
            }

            ProgressBarView(
                ratedCount: viewModel.ratedCount,
                totalCount: viewModel.photoCount
            )

            if (viewModel.viewMode == .rejectedOnly && viewModel.badPhotos.isEmpty) ||
               (viewModel.viewMode == .unratedOnly && viewModel.unratedPhotos.isEmpty) ||
               (viewModel.viewMode == .prizedOnly && viewModel.goodPhotos.isEmpty) {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    switch viewModel.viewMode {
                    case .rejectedOnly:
                        Text("No Rejected Photos")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("All photos are rated Good or unrated.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .prizedOnly:
                        Text("No Prized Photos")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("Rate some photos as Good to see them here.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    default:
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
                    case .prizedOnly:   return viewModel.goodPhotos.count
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
        .overlay(alignment: .leading) {
            HStack(spacing: 0) {
                if showExif {
                    ExifPanelView(
                        isLoading: viewModel.isLoadingExif,
                        exif: viewModel.currentPhotoExif
                    )
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    Divider()
                }

                Color.clear
                    .frame(width: 20)
                    .contentShape(Rectangle())
            }
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    withAnimation(.easeInOut(duration: 0.2)) { showExif = true }
                case .ended:
                    withAnimation(.easeInOut(duration: 0.25)) { showExif = false }
                }
            }
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
        .sheet(isPresented: $viewModel.showCopySheet) {
            CopyGoodPhotosSheet(viewModel: viewModel)
        }
        .alert("Copy Complete", isPresented: $viewModel.showCopyResult) {
            Button("OK") { }
        } message: {
            Text(viewModel.copyResultMessage)
        }
        .onChange(of: viewModel.displayedCurrentPhoto?.displayURL) { _, _ in
            viewModel.loadExifForCurrentPhoto()
        }
        .onAppear {
            viewModel.loadExifForCurrentPhoto()
        }
        .onChange(of: viewModel.showDeletionResult) { _, isShowing in
            if !isShowing { viewModel.hasJustRenamed = false }
        }
    }
}
