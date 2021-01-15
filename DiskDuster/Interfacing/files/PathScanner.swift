//
//  PathScanner.swift
//  DiskDuster
//
//  Created by James Ranson on 12/5/20.
//

import Foundation

var isCanceled: Bool = false

var cacheMatches: Set<String> = []
var logMatches: Set<String> = []
var langMatches: Set<String> = []

let homeDir: String = fm.homeDirectoryForCurrentUser.path
    .replacingOccurrences(of: "Library/Containers/org.ossprime.DiskDuster/Data", with: "")
var userHashDir: String = ""

let tokenUD: String = "$userHashDir"
let tokenAD: String = "$appDir"
let tokenAN: String = "$appName"
let tokenFL: String = "$foreignLang.lproj"

var preferredLanguages: Set<String> = []

func doScan() {
            
    print("home directory calculated to be", homeDir)
    
    userHashDir = getHashDir()
    print("/private/var/folders subdirectory identified as", userHashDir)
    
    preferredLanguages = ["Base", "English"] // so we never delete a Base.lproj
    for lang in Locale.preferredLanguages {
        preferredLanguages.insert(lang)
        if lang.count > 2 {
            // the index of the third character in the language directory name
            let c3: Character = lang[lang.index(lang.startIndex, offsetBy: 2)]
            if (c3 == "-" ) {
                // if it's like en-US, we also add just en
                preferredLanguages.insert(String(lang.prefix(2)))
                // if it's like en-US, we also add en_US with underscore
                preferredLanguages.insert(lang.replacingOccurrences(of: "-", with: "_"))
            } else if ( c3 == "_" ) {
                // if it's like en_US, we also add just en
                preferredLanguages.insert(String(lang.prefix(2)))
                // if it's like en_US, we also add en-US with hyphen
                preferredLanguages.insert(lang.replacingOccurrences(of: "_", with: "-"))
            }
        }
    }
    
    print("preferred languages are", preferredLanguages.sorted())
    
    isCanceled = false
    
    print("Scanning for Caches")
    cacheMatches = []
    for loc in cacheScanLocations {
        if isCanceled {
            return
        }
        let matches = scanLocationPattern(loc: loc)
        for match in matches {
            cacheMatches.insert(match)
        }
    }

    if isCanceled {
        return
    }
    
    print("Scanning for Logs")
    logMatches = []
    for loc in logsScanLocations {
        if isCanceled {
            return
        }
        let matches = scanLocationPattern(loc: loc)
        for match in matches {
            logMatches.insert(match)
        }
    }
    
    if isCanceled {
        return
    }
    
    print("Scanning for Language Files")
    langMatches = []
    for loc in langScanLocations {
        if isCanceled {
            return
        }
        let matches = scanLocationPattern(loc: loc)
        for match in matches {
            langMatches.insert(match)
        }
    }
    
    print("\n")
    
    print("cacheMatches", cacheMatches.sorted())

    print("logMatches", logMatches.sorted())

    print("langMatches", langMatches.sorted())

}

func scanLocationPattern(loc: String) -> Set<String> {
    
    let l = loc.replacingOccurrences(of: "~/", with: homeDir )
        .replacingOccurrences(of: tokenUD, with: userHashDir)
    
    var dirs: Set<String> = [l]

    if loc.contains(tokenAD) {
        dirs = interpolateAppDirs(dirs: dirs)
    }
    
    if loc.contains(tokenAN) {
        dirs = interpolateAppNames(dirs: dirs)
    }

    if loc.contains(tokenFL) {
        dirs = interpolateLangs(dirs: dirs)
    }
    
    var matches: Set<String> = []
    for dir in dirs {
        if fm.fileExists(atPath: dir) {
            matches.insert(dir)
        }
    }
        
    return matches
}

func getHashDir() -> String {
    return "w3/150n67cj6xn6qy6t9pnqflz00000gn"
}

func interpolateAppDirs(dirs: Set<String>) -> Set<String> {
    var matches: Set<String> = []
    for dir in dirs {
        if let range: Range<String.Index> = dir.range(of: tokenAD) {
            var pdir = String(dir.prefix(dir.distance(from: dir.startIndex, to: range.lowerBound)))
            if pdir.hasSuffix("/") {
                pdir = String(pdir.prefix(pdir.count-1))
            }
            if !fm.fileExists(atPath: pdir) {
                continue
            }
            do {
                let appDirs = try fm.contentsOfDirectory(atPath: pdir)
                for appDir in appDirs {
                    matches.insert(dir.replacingOccurrences(of: tokenAD, with: appDir))
                }
            } catch {
                print("Unexpected error: \(error).")
            }
        }
    }
    return matches
}

func interpolateAppNames(dirs: Set<String>) -> Set<String> {
    var matches: Set<String> = []
    for dir in dirs {
        if let range: Range<String.Index> = dir.range(of: tokenAN) {
            var pdir = String(dir.prefix(dir.distance(from: dir.startIndex, to: range.lowerBound)))
            if pdir.hasSuffix("/") {
                pdir = String(pdir.prefix(pdir.count-1))
            }
            if !fm.fileExists(atPath: pdir) {
                continue
            }
            do {
                let appDirs = try fm.contentsOfDirectory(atPath: pdir)
                for appDir in appDirs {
                    matches.insert(dir.replacingOccurrences(of: tokenAN, with: appDir))
                }
            } catch {
                print("Unexpected error: \(error).")
            }
        }
    }
    return matches
}

func interpolateLangs(dirs: Set<String>) -> Set<String> {
    var matches: Set<String> = []
    for dir in dirs {
        var dirMatches: Set<String> = []
        if let range: Range<String.Index> = dir.range(of: tokenFL) {
            var pdir = String(dir.prefix(dir.distance(from: dir.startIndex, to: range.lowerBound)))
            if pdir.hasSuffix("/") {
                pdir = String(pdir.prefix(pdir.count-1))
            }
            if !fm.fileExists(atPath: pdir) {
                continue
            }
            do {
                let appDirs = try fm.contentsOfDirectory(atPath: pdir)
                var i: Int = 0
                var foundPreferred: Bool = false
                for langDir in appDirs {
                    i += 1
                    if langDir.hasSuffix(".lproj") {
                        let langPre: String = langDir.replacingOccurrences(of: ".lproj", with: "")
                        if preferredLanguages.contains(langPre) {
                            foundPreferred = true
                            continue
                        }
                        dirMatches.insert(dir.replacingOccurrences(of: tokenFL, with: langDir))
                    }
                }
                // this ensures we only recommend removing an App's unpreferred langauges if at least
                // 1 preferred language remains available in the app Resources
                if dirMatches.count > 0 && dirMatches.count < i && foundPreferred {
                    matches = matches.union(dirMatches)
                }
            } catch {
                print("Unexpected error: \(error).")
            }
        }
    }
    
    return matches
}

/*
 
 foreignLanguage
 appDir
 appName
 userHashDir √
 
 */
