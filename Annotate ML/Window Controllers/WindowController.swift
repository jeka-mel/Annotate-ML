//
//  WindowController.swift
//  Annotate ML
//
//  Created by Emily Blackwell on 21/10/2019.
//  Copyright © 2019 Emily Blackwell. All rights reserved.
//

import Cocoa

class WindowController: NSWindowController {
	
	/// this gets posted whenever this window becomes active
	static let documentAvailable = NSNotification.Name(rawValue: "documentIsAvailable")
	
	@IBOutlet weak var saveIndicator: NSProgressIndicator?
	@IBOutlet var shareMenu: NSMenu!
	
	weak var viewController: ViewController?
	weak var labelsWC: NSWindowController?
	
	var openImagePanel: NSOpenPanel!
	var exportPanel: NSSavePanel!
	var lastURL: URL?
    
    lazy final var importAnnotationsPanel: NSOpenPanel = {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["annotateml"]
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        return panel
    }()

    override func windowDidLoad() {
        super.windowDidLoad()

		window!.acceptsMouseMovedEvents = true
		
		saveIndicator?.isHidden = true
    
		openImagePanel = NSOpenPanel()
		openImagePanel.allowedFileTypes = NSImage.imageTypes
		openImagePanel.allowsMultipleSelection = true
		openImagePanel.resolvesAliases = true

		exportPanel = NSSavePanel()
		
		let splitViewController = (contentViewController as! SplitViewController)
		self.viewController = splitViewController.editor

		NC.observe(NSWindow.didBecomeKeyNotification, using: #selector(didBecomeActive(notification:)), on: self, watch: self.window)

		NC.observe(NSWindow.willCloseNotification, using: #selector(willClose(notification:)), on: self, watch: self.window)
		
		NC.observe(PreferencesViewController.preferencesChanged, using: #selector(changeTitlebarAppearance(notification:)), on: self)
		
		// update our title/tool bar appearance
		
		let usesModernLook = UserDefaults.standard.bool(forKey: kPreferencesCalendarStyleTitlebar)
		
		useModernTitlebarAppearance(usesModernLook)
    }
	
	// MARK: Notification Actions
	
	@objc func didBecomeActive(notification: NSNotification) {
		// Allow our labels view to update its UI for the currently-active document
		NC.post(WindowController.documentAvailable, object: self.document)
	}
	
	@objc func willClose(notification: NSNotification) {

		// unregister our observers
		NC.stopObserving(NSWindow.didBecomeKeyNotification, on: self, specifically: self.window)
		
		NC.stopObserving(NSWindow.willCloseNotification, on: self, specifically: self.window)
		
		NC.stopObserving(PreferencesViewController.preferencesChanged, on: self)
	}
	
	@objc func changeTitlebarAppearance(notification: NSNotification) {
		guard let changes = notification.userInfo as? [String: Bool],
			let usesModernLook = changes[kPreferencesCalendarStyleTitlebar] else {
			return
		}
		
		useModernTitlebarAppearance(usesModernLook)
	}
	
	private func useModernTitlebarAppearance(_ modern: Bool) {
		window?.titleVisibility = modern ? .hidden : .visible
		
		if !modern {
			window?.toolbar?.displayMode = .iconAndLabel
		}
	}
	
	// MARK: View Actions
	
	@IBAction func zoomControl(sender: NSSegmentedControl) {
		guard sender.selectedSegment == 1 else {
			zoomOut(sender: sender)
			return
		}
		
		zoomIn(sender: sender)
	}
	
	@IBAction func zoomIn(sender: AnyObject) {
		viewController?.zoom(zoomIn: true)
	}
	
	@IBAction func zoomOut(sender: AnyObject) {
		viewController?.zoom(zoomIn: false)
	}
	
	@IBAction func zoomReset(sender: AnyObject) {
		viewController?.zoomReset()
	}
	
	@IBAction func showLabels(sender: AnyObject) {
		performSegue(withIdentifier: "show labels", sender: sender)
	}
    
    @IBAction func deleteSelectedPhoto(sender: AnyObject) {
        viewController?.deleteSelectedPhotoWithSender(sender)
    }
	
	// MARK: Navigation Actions
	
	@IBAction func navigatePhoto(sender: NSSegmentedControl) {
		guard sender.selectedSegment == 1 else {
			previousPhoto(sender: sender)
			return
		}
		
		nextPhoto(sender: sender)
	}
	
	@IBAction func previousPhoto(sender: AnyObject) {
		viewController?.previousPhoto()
	}
	
	@IBAction func nextPhoto(sender: AnyObject) {
		viewController?.nextPhoto()
	}
	
	// MARK: File Actions
	
	@IBAction func openImages(sender: AnyObject) {
		openImagePanel.beginSheetModal(for: window!) { response in
			guard response == .OK else {
				return
			}
			
			self.viewController?.addImages(images: self.openImagePanel.urls)
		}
	}
    
    @IBAction func importAnnotations(sender: AnyObject) {
        importAnnotationsPanel.begin { [unowned self] response in
            guard response == .OK else {
                return
            }
            guard let url = self.importAnnotationsPanel.url else {
                return
            }
            self.viewController?.importAnnotations(from: url)
        }
    }
	
	@IBAction func showShareMenu(sender: NSButton) {
		shareMenu.popUp(positioning: shareMenu.items.first, at: sender.frame.origin, in: sender)
	}
	
	@IBAction func shareDocument(sender: AnyObject) {
		
		if document!.fileURL! == nil {
			
			/*
			For some reason sharing doesn't work if the document
			isn't saved, so instead of doing nothing, let's just tell the user
			why sharing is currently unavailable for them.
			*/
			
			let alert = NSAlert()
			alert.alertStyle = .warning
			
			alert.messageText = "S0".l
			alert.informativeText = "SUIT".l
			
			alert.addButton(withTitle: "Ok".l)
			alert.runModal()
			
			return
		}
		
		var service: NSSharingService.Name!
		
		switch sender.tag {
		case 0:
			service = .sendViaAirDrop
			
		case 1:
			service = .cloudSharing
			
		case 2:
			service = .composeEmail
			
		case 3:
			service = .composeMessage
			
		default:
			return
		}
		
		// share our document using the selected service
		let sharingService = NSSharingService(named: service)
		sharingService?.perform(withItems: [document as! Document])
	}
	
	// MARK: Other Actions
	
	func setIndicator(isVisible: Bool) {
		saveIndicator?.isHidden = !isVisible
		isVisible ? saveIndicator?.startAnimation(self) : saveIndicator?.stopAnimation(self)
	}
}

extension WindowController {
	
	// MARK: Document Actions

	private func exportCompletion(url: URL, success: Bool) {
		
		DispatchQueue.main.async {
			
			self.setIndicator(isVisible: false)
			
			// show the appropriate message
			let alert = NSAlert()
			
			alert.alertStyle = success ? .informational : .critical
			
			alert.messageText = success ? "E1".l : "E0".l
			
			alert.informativeText = success
				? "\("EIT1".l) \(url.path)."
				: "EIT0".l
			
			alert.addButton(withTitle: "Ok".l)
			alert.runModal()
		}
	}
	
	private func exportDocument(export: @escaping (Document, URL) -> Void) {
		
		exportPanel.beginSheetModal(for: window!) { response in
			
			guard response == .OK, let url = self.exportPanel.url,
				let document = self.viewController?.document else {
				return
			}
			
			self.setIndicator(isVisible: true)
			
			DispatchQueue.global(qos: .userInteractive).async {
				export(document, url)
			}
		}
	}
	
	@IBAction func export(sender: AnyObject) {
		self.exportDocument { document, url in
			document.exportCreateML(url: url) {
				self.exportCompletion(url: url, success: $0)
			}
		}
	}
	
	@IBAction func exportTuri(sender: AnyObject) {
		self.exportDocument { document, url in
			document.exportTuriCreate(url: url) {
				self.exportCompletion(url: url, success: $0)
			}
		}
	}
}

extension WindowController {
	
	// MARK: Segues
	
	override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
		if segue.identifier == "show labels" {
			let wc = segue.destinationController as! NSWindowController
			let vc = wc.contentViewController as! LabelsViewController
			
			vc.document = viewController?.document
			labelsWC = wc
		}
	}
}
