//
//  ViewController.swift
//
//  Created by Oleksandr Harmash
//  Copyright © Oleksandr Harmash. All rights reserved.
//

import Cocoa
import Zip

class ViewController: NSViewController {
    
    @IBOutlet weak var originalDirPathControl: NSPathControl!
    @IBOutlet weak var targetDirPatchControl: NSPathControl!
    @IBOutlet weak var optimizeButton: NSButton!
    @IBOutlet weak var stopButton: NSButton!
    @IBOutlet weak var activityView: NSProgressIndicator!
    @IBOutlet var outputText: NSTextView!
    
    var isRunning = false
    var optimizeTask: Process!
    var outputPipe: Pipe!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override var representedObject: Any? {
        didSet { }
    }
    
    //MARK: - Private Methods
    
    private func startTask() {
        
        outputText.string = ""
        
        guard let originalUrl = originalDirPathControl.url else {
            NSAlert.show(with: Literals.alert.warning, text: Literals.alert.hitOriginPath)
            return
        }
        guard let targetUrl = targetDirPatchControl.url else {
            NSAlert.show(with: Literals.alert.warning, text: Literals.alert.hitTargetPath)
            return
        }
        
        //check if empty folder
        do {
            let dsstoreUrl = targetUrl.appendingPathComponent(".DS_Store")
            let urls = try FileManager.default.contentsOfDirectory(at: targetUrl, includingPropertiesForKeys: nil, options: [])
         if (!urls.filter{ $0 != dsstoreUrl }.isEmpty) {
                NSAlert.show(with: Literals.alert.warning, text: Literals.alert.hitEmptyFolder) { delete in
                    if delete {
                        for url in urls {
                            do {
                                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                            } catch let error {
                                debugPrint(error.localizedDescription)
                            }
                        } //for
                    } //delete
                }
                return
            }
        } catch let error {
            debugPrint(error.localizedDescription)
        }

        let originalLocation = originalUrl.path
        let targetLocation = targetUrl.path
        
        var arguments: [String] = []
        arguments.append(originalLocation)
        arguments.append("-o")
        arguments.append(targetLocation)
        
        optimizeButton.isEnabled = false
        activityView.startAnimation(self)
        
        runScript(arguments)
    }
    
    private func runScript(_ arguments: [String]) {
        isRunning = true
        
        let taskQueue = DispatchQueue.global(qos: .background)
        
        taskQueue.async {
            
            guard let path = Bundle.main.path(forResource: "copySceneKitAssets", ofType: "command") else { return }
            
            self.optimizeTask = Process()
            self.optimizeTask.launchPath = path
            self.optimizeTask.arguments = arguments
            
            self.optimizeTask.terminationHandler = {
                task in DispatchQueue.main.async(execute: {
                    self.optimizeButton.isEnabled = true
                    self.activityView.stopAnimation(self)
                    self.isRunning = false
                    
                    self.createZipArchive()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                        self.outputText.string = self.outputText.string + "\n" + "Done"
                        let range = NSRange(location: nextOutput.count, length: 0)
                        self.outputText.scrollRangeToVisible(range)
                    })
                })
            }
            
            self.captureOutput(self.optimizeTask)
            
            self.optimizeTask.launch()
            self.optimizeTask.waitUntilExit()
        }
    }
    
    private func createZipArchive() {
        guard let targetUrl = targetDirPatchControl.url else { return }
        
        do {
            let zipFilePath = targetUrl.appendingPathComponent("\(targetUrl.lastPathComponent).zip")
            try Zip.zipFiles(paths: [targetUrl], zipFilePath: zipFilePath, password: nil, progress: { progress in
                debugPrint("[DEBUG] progress archive \(progress)")
            })
            do {
                let urls = try FileManager.default.contentsOfDirectory(at: targetUrl, includingPropertiesForKeys: nil, options: [])
                for url in urls {
                    if url != zipFilePath {
                        do {
                            try FileManager.default.removeItem(at: url)
                        } catch let error {
                            debugPrint(error.localizedDescription)
                        }
                    }
                }
            } catch let error {
                debugPrint(error.localizedDescription)
            }
        } catch let error {
            debugPrint(error.localizedDescription)
        }
    }
    
    private func captureOutput(_ task: Process) {
        outputPipe = Pipe()
        task.standardOutput = outputPipe
        
        outputPipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable, object: outputPipe.fileHandleForReading, queue: nil) { notification in
            
            let output = self.outputPipe.fileHandleForReading.availableData
            let outputString = String(data: output, encoding: .utf8) ?? ""
            
            DispatchQueue.main.async(execute: {
                self.outputText.string = self.outputText.string + "\n" + outputString
                
                let range = NSRange(location: nextOutput.count, length: 0)
                self.outputText.scrollRangeToVisible(range)
            })
            self.outputPipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
        }
    }
    
    //MARK: - Actions
    
    @IBAction func optimizeButtonPressed(_ sender: NSButton) {
        startTask()
    }
    
    @IBAction func stopButtonPressed(_ sender: NSButton) {
        if isRunning {
            optimizeTask.terminate()
        }
    }
}
