//
//  ApodViewController.swift
//  Jasy
//
//  Created by Vladimir Espinola on 10/02/2019.
//  Copyright © 2019 Vladimir Espinola. All rights reserved.
//

import UIKit
import WebKit
import RxSwift
import Nuke
import RxNuke
import SnapKit
import FirebaseAnalytics

class ApodViewController: UIViewController {
    
    @IBOutlet weak var picture: UIImageView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageScrollView: UIScrollView!
    @IBOutlet weak var explanationTextView: UITextView!
    
    private var disposeBag = DisposeBag()
    var apod: ApodModel!
    
    private lazy var shareButton: UIBarButtonItem! = {
        let button = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: nil)
        button.tintColor = .white
        return button
    }()
    
    private lazy var webView: WKWebView! = {
        let webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: self.view.frame, configuration: webViewConfiguration)
        webView.backgroundColor = .black
        view.addSubview(webView)
        
        webView.snp.makeConstraints { $0.edges.equalTo(self.picture) }
        
        return webView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        binding()
    }
    
    deinit {
        print("deallocated apod viewController")
    }
    
    private func setup() {
        title = apod.prettyDate
        
        view.backgroundColor = .black
        
        picture.contentMode = .scaleAspectFit
        picture.backgroundColor = .black
        
        imageScrollView.minimumZoomScale = 1.0
        imageScrollView.maximumZoomScale = 7.0
        imageScrollView.delegate = self
        
        scrollView.backgroundColor = UIColor.black
        
        let titleAttributedString = NSMutableAttributedString()
        
        let leftAlignmentStype = NSMutableParagraphStyle()
        leftAlignmentStype.alignment = .left
        
        let centerAlignmentStype = NSMutableParagraphStyle()
        centerAlignmentStype.alignment = .center
        
        titleAttributedString.append(NSMutableAttributedString(string: apod.title, attributes: [
            NSAttributedString.Key.font             : UIFont.helveticaNeueBold21,
            NSAttributedString.Key.foregroundColor  : UIColor.white,
            NSAttributedString.Key.paragraphStyle   : centerAlignmentStype
        ]))
        
        titleAttributedString.append(NSMutableAttributedString(string: "\n\n\(apod.explanation)", attributes: [
            NSAttributedString.Key.font             : UIFont.helveticaNeue14,
            NSAttributedString.Key.foregroundColor  : UIColor.white,
            NSAttributedString.Key.paragraphStyle   : leftAlignmentStype
        ]))
        
        if let copyright = apod.copyright {
            titleAttributedString.append(NSMutableAttributedString(string: "\n\nCopyright: ", attributes: [
                NSAttributedString.Key.font             : UIFont.helveticaNeueBold14,
                NSAttributedString.Key.foregroundColor  : UIColor.white,
                NSAttributedString.Key.paragraphStyle   : leftAlignmentStype
                ]))
            
            titleAttributedString.append(NSMutableAttributedString(string: "\(copyright)", attributes: [
                NSAttributedString.Key.font             : UIFont.helveticaNeue14,
                NSAttributedString.Key.foregroundColor  : UIColor.white,
                NSAttributedString.Key.paragraphStyle   : leftAlignmentStype
            ]))
        }
        
        explanationTextView.attributedText = titleAttributedString
        explanationTextView.isEditable = false
        explanationTextView.isScrollEnabled = false
        explanationTextView.isSelectable = true
        explanationTextView.layer.cornerRadius = JMetric.cornerRadius
        explanationTextView.textContainerInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        explanationTextView.contentOffset = .zero

        navigationItem.rightBarButtonItem = shareButton
        
        Analytics.logEvent(AnalyticsKeys.showInfo, parameters: nil)
    }
    
    private func binding() {
        
        
        if let image = JFileManager.shared.getImageTo(path: apod.highImageName) {
            picture.image = image
        } else if let lowUrl = apod.lowURL, let hdurl = apod.highURL {
            let pipeline = ImagePipeline.shared
            
            Observable.concat(pipeline.rx.loadImage(with: lowUrl).orEmpty,
                              pipeline.rx.loadImage(with: hdurl).orEmpty)
                .subscribe(onNext: { [weak self] in
                    guard let strongSelf = self, let apodModel = strongSelf.apod else { return }
                    strongSelf.picture.image = $0.image
                    JFileManager.shared.writeImageTo(path: apodModel.highImageName, image: $0.image)
                })
                .disposed(by: disposeBag)
        } else {
            let myURL = URL(string: apod.url!)
            let videoRequest = URLRequest(url: myURL!)
            webView.load(videoRequest)
        }
        
        shareButton.rx.tap
            .asDriver()
            .drive(onNext: { [unowned self] in
                
                var items: [Any] = [
                    "\(self.apod.title):",
                    self.apod.explanation
                ]
                
                if let image = self.picture.image {
                    items.append(image)
                }
                
                if let highURL = self.apod.highURL {
                    items.append(highURL)
                } else if let lowURL = self.apod.lowURL {
                    items.append(lowURL)
                }
                
                Utilities.share(items: items, in: self)
            })
            .disposed(by: disposeBag)
    }
}

extension ApodViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return picture
    }
}
