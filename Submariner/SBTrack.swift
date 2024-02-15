//
//  SBTrack+CoreDataClass.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-04-23.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//
//

import Foundation
import CoreData
import UniformTypeIdentifiers

@objc(SBTrack)
public class SBTrack: SBMusicItem {
    public override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        if key == "durationString" {
            return Set(["duration"])
        } else if key == "playingImage" {
            return Set(["isPlaying"])
        } else if key == "onlineImage" {
            return Set(["isLocal"])
        }
        return Set()
    }
    
    @objc var durationString: String? {
        self.willAccessValue(forKey: "duration")
        let ret = String(timeInterval: TimeInterval(duration?.intValue ?? 0))
        self.didAccessValue(forKey: "duration")
        return ret
    }
    
    @objc func streamURL() -> URL? {
        if let isLocal = self.isLocal, isLocal.boolValue,
           let path = self.path,
           FileManager.default.fileExists(atPath: path) {
            return URL.init(fileURLWithPath: path)
        } else if let server = self.server, let url = server.url {
            var parameters = server.getBaseParameters()
            parameters["maxBitRate"] = UserDefaults.standard.string(forKey: "maxBitRate")
            parameters["id"] = self.itemId
            
            return URL.URLWith(string: url, command: "rest/stream.view", parameters: parameters)
        }
        return nil
    }
    
    @objc func downloadURL() -> URL? {
        if let server = self.server, let url = server.url {
            var parameters = server.getBaseParameters()
            parameters["maxBitRate"] = UserDefaults.standard.string(forKey: "maxBitRate")
            parameters["id"] = self.itemId
            
            return URL.URLWith(string: url, command: "rest/download.view", parameters: parameters)
        }
        return nil
    }
    
    @objc var playingImage: NSImage? {
        if let playing = self.isPlaying, playing.boolValue {
            return NSImage(systemSymbolName: "speaker.fill", accessibilityDescription: "Playing")
        }
        return nil
    }
    
    @objc var coverImage: NSImage {
        // change this if imageRepresentation is optimized
        if let album = self.album {
            return album.imageRepresentation() as! NSImage
        }
        return SBAlbum.nullCover!
    }
    
    @objc var artistString: String? {
        if let album = self.album,
           let albumArtist = album.artist,
           let albumArtistName = albumArtist.itemName {
            return albumArtistName
        }
        return artistName
    }
    
    @objc var albumString: String? {
        return self.album?.itemName
    }
    
    @objc var onlineImage: NSImage {
        if self.localTrack != nil || self.isLocal?.boolValue == true {
            return NSImage(systemSymbolName: "bolt.horizontal.fill", accessibilityDescription: "Cached")!
        }
        return NSImage(systemSymbolName: "bolt.horizontal", accessibilityDescription: "Online")!
    }
    
    @objc func isVideo() -> Bool {
        if let contentType = self.contentType,
           let utType = UTType(mimeType: contentType) {
            return utType.conforms(to: .video)
        }
        return false
    }
    
    @objc func macOSCompatibleContentType() -> String? {
        if let contentType = self.contentType,
           contentType == "audio/x-flac" {
            return "audio/flac"
        }
        return self.contentType
    }
    
    // #MARK: - AppleScript wrappers
    
    @objc var objectIDString: String {
        return objectID.uriRepresentation().absoluteString
    }
    
    @objc var coverImageURL: NSString? {
        return album?.cover?.imagePath
    }
    
    // #MARK: - Core Data insert compatibility shim
    
    @objc(insertInManagedObjectContext:) class func insertInManagedObjectContext(context: NSManagedObjectContext) -> SBTrack {
        let entity = NSEntityDescription.entity(forEntityName: "Track", in: context)
        return NSEntityDescription.insertNewObject(forEntityName: entity!.name!, into: context) as! SBTrack
    }
}
