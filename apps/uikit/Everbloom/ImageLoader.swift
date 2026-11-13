import UIKit

/// Loads remote images with an in-memory cache, decoding off the main thread.
final class ImageLoader {
    static let shared = ImageLoader()

    private let cache = NSCache<NSURL, UIImage>()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 16 * 1024 * 1024, diskCapacity: 0)
        session = URLSession(configuration: config)
        cache.totalCostLimit = 96 * 1024 * 1024
    }

    func cached(_ url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func load(_ url: URL, completion: @escaping (UIImage?) -> Void) -> URLSessionDataTask {
        let task = session.dataTask(with: url) { [cache] data, _, _ in
            var image: UIImage?
            if let data, let decoded = UIImage(data: data) {
                image = decoded.preparingForDisplay() ?? decoded
                if let image {
                    let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
                    cache.setObject(image, forKey: url as NSURL, cost: cost)
                }
            }
            DispatchQueue.main.async { completion(image) }
        }
        task.resume()
        return task
    }
}

/// Aspect-fill image view that shows the surface color until its image arrives.
final class RemoteImageView: UIImageView {
    private var task: URLSessionDataTask?
    private var currentURL: URL?

    init(cornerRadius: CGFloat = 0) {
        super.init(frame: .zero)
        contentMode = .scaleAspectFill
        clipsToBounds = true
        backgroundColor = Theme.surface
        layer.cornerRadius = cornerRadius
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { fatalError() }

    func setURL(_ url: URL?) {
        if url == currentURL, image != nil { return }
        task?.cancel()
        task = nil
        currentURL = url
        image = nil
        guard let url else { return }
        if let cached = ImageLoader.shared.cached(url) {
            image = cached
            return
        }
        task = ImageLoader.shared.load(url) { [weak self] image in
            guard let self, self.currentURL == url else { return }
            self.image = image
            self.task = nil
        }
    }
}
