import UIKit

// TODO: временная штука, надо будет ее заменить на что-то более хитрое, вроде CATiledLayer
final class ZoomingImageView: UIView {
    
    private let scrollView = ZoomingImageScrollView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        scrollView.clipsToBounds = false
        
        addSubview(scrollView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
    }
    
    var image: UIImage? {
        get { return scrollView.image }
        set { scrollView.image = newValue }
    }
    
    func setImageRotation(angle: CGFloat) {
        scrollView.setImageRotation(angle)
    }
}

private class ZoomingImageScrollView: UIScrollView, UIScrollViewDelegate {
    
    private var image: UIImage? {
        get { return imageView.image }
        set {
            zoomScale = 1
            
            imageView.image = newValue
            imageView.sizeToFit()
            
            configureForCurrentImageSize()
        }
    }
    
    // MARK: - Subviews
    
    private let imageView = ImageViewWrapper()
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        alwaysBounceHorizontal = true
        alwaysBounceVertical = true
        bouncesZoom = true
        decelerationRate = UIScrollViewDecelerationRateFast
        delegate = self
        
        addSubview(imageView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UIView
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // center image view as it becomes smaller than the size of the screen
        
        var imageFrame = imageView.frame
        
        // center horizontally
        if imageFrame.size.width < bounds.size.width {
            imageFrame.origin.x = (bounds.size.width - imageFrame.size.width) / 2
        } else {
            imageFrame.origin.x = 0
        }
        
        // center vertically
        if imageFrame.size.height < bounds.size.height {
            imageFrame.origin.y = (bounds.size.height - imageFrame.size.height) / 2
        } else {
            imageFrame.origin.y = 0
        }
        
        imageView.frame = imageFrame
    }
    
    override var frame: CGRect {
        willSet {
            if newValue.size != frame.size {
                prepareForResize()
            }
        }
        didSet {
            if frame.size != oldValue.size {
                recoverFromResizing()
            }
        }
    }
    
    // MARK: - Configure scrollView to display new image
    
    private var imageSize: CGSize {
        return imageView.image?.size ?? .zero
    }
    
    private func configureForCurrentImageSize() {
        contentSize = imageSize
        setMaxMinZoomScalesForCurrentBounds()
        zoomScale = minimumZoomScale
    }
    
    private func setMaxMinZoomScalesForCurrentBounds() {
        
        let imageSize = self.imageSize
        
        var minScale = max(
            bounds.size.width  / imageSize.width,   // the scale needed to perfectly fit the image width-wise
            bounds.size.height / imageSize.height   // the scale needed to perfectly fit the image height-wise
        )
        
        // on high resolution screens we have double the pixel density, so we will be seeing every pixel if we limit the
        // maximum zoom scale to 0.5.
        let maxScale = CGFloat(1) / UIScreen.mainScreen().scale
        
        // don't let minScale exceed maxScale (if the image is smaller than the screen,
        // we don't want to force it to be zoomed)
        if (minScale > maxScale) {
            minScale = maxScale
        }
        
        maximumZoomScale = 10   // TODO
        minimumZoomScale = minScale
        print("min scale = \(minimumZoomScale), max scale = \(maximumZoomScale)")
    }
    
    // MARK: - Rotation support
    
    private var pointToCenterAfterResize = CGPoint.zero
    private var scaleToRestoreAfterResize = CGFloat(1)
    
    private func prepareForResize() {
        
        pointToCenterAfterResize = convertPoint(bounds.center, toView: imageView)
        scaleToRestoreAfterResize = zoomScale
        
        // If we're at the minimum zoom scale, preserve that by returning 0, which will be converted to the minimum
        // allowable scale when the scale is restored.
        if scaleToRestoreAfterResize <= minimumZoomScale + CGFloat(FLT_EPSILON) {
            scaleToRestoreAfterResize = 0
        }
    }
    
    private func recoverFromResizing() {
        
        setMaxMinZoomScalesForCurrentBounds()
        
        // Step 1: restore zoom scale, first making sure it is within the allowable range.
        let maxZoomScale = max(minimumZoomScale, scaleToRestoreAfterResize)
        zoomScale = min(maximumZoomScale, maxZoomScale)
        
        // Step 2: restore center point, first making sure it is within the allowable range.
        
        // 2a: convert our desired center point back to our own coordinate space
        let boundsCenter = convertPoint(pointToCenterAfterResize, fromView: imageView)
        
        // 2b: calculate the content offset that would yield that center point
        var offset = CGPoint(
            x: bounds.centerX - bounds.size.width / 2,
            y: bounds.centerY - bounds.size.height / 2
        )
        
        // 2c: restore offset, adjusted to be within the allowable range
        let maxOffset = maximumContentOffset()
        let minOffset = minimumContentOffset()
        
        let realMaxOffsetX = min(maxOffset.x, offset.x)
        offset.x = max(minOffset.x, realMaxOffsetX)
        
        let realMaxOffsetY = min(maxOffset.y, offset.y)
        offset.y = max(minOffset.y, realMaxOffsetY)
        
        contentOffset = offset
    }
    
    private func minimumContentOffset() -> CGPoint {
        return .zero
    }
    
    private func maximumContentOffset() -> CGPoint {
        return CGPoint(
            x: contentSize.width - bounds.size.width,
            y: contentSize.height - bounds.size.height
        )
    }
    
    private var imageRotation = CGFloat(0)
    private var imageScale = CGFloat(1)
    
    func setImageRotation(angle: CGFloat) {
        
        let radians = angle * CGFloat(M_PI) / 180
        let scale = scaleToFillBoundsWithImageRotatedBy(Double(radians))
        
        imageView.imageTransform = CGAffineTransformMakeRotation(radians)
        
        imageRotation = radians
        
        minimumZoomScale = scale
        zoomScale = scale
        debugPrint("scale =\(scale), zoomScale = \(zoomScale)")
    }
    
    // MARK: - UIScrollViewDelegate
    
    @objc func scrollViewDidScroll(scrollView: UIScrollView) {
        imageView.setFocusPoint(bounds.center, inView: self)
    }
    
    @objc func scrollViewWillEndDragging(
        scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        
        let angle = CGFloat(imageRotation)
        let sourceCenter = bounds.center
        
        // 1. Находим прямоугольник, повернутый относительно исходного на угол angle и описанный
        // вокруг него (все вершины исходного прямоугольника лежат на сторонах искомого)
        var enclosingRect = bounds.enclosingRectRotatedBy(angle)
        
        // 2. Находим frame изображения в повернутой системе координат
        let imageRect = imageView.bounds
        
        debugPrint("bounds = \(bounds)")
        
        // 3. Двигаем enclosingRect так, чтобы он оказался внутри imageRect
        debugPrint("enclosingRect before = \(enclosingRect)")
        enclosingRect.left = max(enclosingRect.left, imageRect.left)
        enclosingRect.top = max(enclosingRect.top, imageRect.top)
        enclosingRect.right = min(enclosingRect.right, imageRect.right)
        enclosingRect.bottom = min(enclosingRect.bottom, imageRect.bottom)
        debugPrint("enclosingRect after = \(enclosingRect)")
        
        // 4. Транслируем центр полученного прямоугольника в исходную систему координат
        let translateTransform = CGAffineTransformMakeTranslation(sourceCenter.x, sourceCenter.y)
        let rotationTransform = CGAffineTransformMakeRotation(-angle)
        let reverseTransform = CGAffineTransformConcat(
            CGAffineTransformConcat(CGAffineTransformInvert(translateTransform), rotationTransform),
            translateTransform
        )
        
        let targetCenter = CGPointApplyAffineTransform(enclosingRect.center, reverseTransform)
        debugPrint("targetCenter = \(targetCenter)")
        
        // 5. Рассчитываем contentOffset, при котором центром bounds окажется targetCenter
        targetContentOffset.memory = CGPoint(
            x: targetCenter.x - bounds.size.width / 2,
            y: targetCenter.y - bounds.size.height / 2
        )
        
        debugPrint("targetContentOffset = \(targetContentOffset.memory)")
    }
    
    @objc func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    // MARK: - Private
    
    private func scaleToFillBoundsWithImageRotatedBy(angle: Double) -> CGFloat {
        
        let pi = M_PI
        let containerSize = bounds.size
        
        var theta = fabs(angle - 2 * pi * trunc(angle / pi / 2) - pi)
        if theta > pi / 2 {
            theta = fabs(pi - theta)
        }
        
        let H = Double(containerSize.height)
        let W = Double(containerSize.width)
        let h = Double(contentSize.height)
        let w = Double(contentSize.width)
        
        let scale1 = (H * cos(theta) + W * sin(theta)) / h
        let scale2 = (H * sin(theta) + W * cos(theta)) / w
        
        return CGFloat(max(scale1, scale2))
    }
}