//
//  HotKey.swift
//  QuickCopy
//
//  Created by 特力更 on 2018/8/26.
//  Copyright © 2018 Ligeng. All rights reserved.
//

import Foundation
import SQLite
import HotKey

class HK: Model {
    
    var id:Int64?
    var text:String! = ""
    var shortcut: String! = ""
    var note: String?
    var visible = true
    
    static let table_name = "hks"
    static let id_col = Expression<Int64>("id")
    static let text_col = Expression<String>("text")
    static let visible_col = Expression<Bool>("visible")
    static let note_col = Expression<String?>("note")
    static let keys_col = Expression<String>("keys")

    var hotkey: HotKey? = nil
    
    required override init() {
        super.init()
    }
    
    init(id: Int64, text: String!, shortcut: String!, note: String?, visible: Bool) {
        super.init()
        
        self.id = id
        self.text = text
        self.shortcut = shortcut
        self.note = note
        self.visible = visible
        
        self.setHotKey()
    }
    
    static public func select_all() -> [HK] {
        let db = openDB()
        let hks = Table(HK.table_name)
        var result: [HK] = []
        
        do {
            for hk in try db.prepare(hks) {
                let hk_obj = HK(id: hk[id_col],
                                text: hk[text_col],
                                shortcut: hk[keys_col],
                                note: hk[note_col],
                                visible: hk[visible_col])
                result.append(hk_obj)
            }
        } catch {
            print("failed to select all")
        }
        
        return result
    }
    
    static func setup() {
        let db = openDB()
        let hks = Table(HK.table_name)
        
        try! db.run(hks.create(ifNotExists: true) { t in
            t.column(id_col, primaryKey: .autoincrement)
            t.column(text_col)
            t.column(visible_col, defaultValue: true)
            t.column(keys_col, unique: true)
            t.column(note_col)
        })
    }
    
    public func break_text(at: Int = 10) -> String! {
        if !self.visible {
            return String(repeating: "*", count: self.text.count > at ? at : self.text.count)
        }
        return TextUtil.wrap(text: self.text, at: at)
    }
    
    public func setVisible(newValue: Bool) {
        guard self.id != nil else {
            return
        }
        
        let db = HK.openDB()
        let row = Table(HK.table_name).filter(HK.id_col == self.id!)
        do {
            if try db.run(row.update(HK.visible_col <- newValue)) > 0 {
                self.visible = newValue
            } else {
                print("Failed in updating visible field")
            }
        } catch {
            print("update failed: \(error)")
        }
    }
    
    public func delete() {
        guard self.id != nil else {
            return
        }
        
        let db = HK.openDB()
        let row = Table(HK.table_name).filter(HK.id_col == self.id!)
        do {
            if try db.run(row.delete()) <= 0 {
                print("Failed in updating visible field")
            }
        } catch {
            print("update failed: \(error)")
        }
    }

    func setHotKey() {
        if self.shortcut == nil {
            return
        }
        
        let keycodes = self.shortcut.split(separator: ",")
        let shortcut = MASShortcut(keyCode: UInt(keycodes[0])!, modifierFlags: UInt(keycodes[1])!)
        hotkey = HotKey(carbonKeyCode: (shortcut?.carbonKeyCode)!, carbonModifiers: (shortcut?.carbonFlags)!)
        hotkey?.keyDownHandler = {
            TextUtil.copy(text: self.text)
        }
    }
    
    public func save() {
        let db = HK.openDB()
        let hks = Table(HK.table_name)
        
        if self.id != nil {
            do {
                let row = hks.filter(HK.id_col == self.id!)
                if try db.run(row.update(HK.text_col <- self.text, HK.visible_col <- self.visible,
                                         HK.note_col <- self.note, HK.keys_col <- self.shortcut)) > 0 {
                    setHotKey()
                } else {
                    print("Updated 0 line")
                }
            } catch {
                print("update failed: \(error)")
            }
        } else {
            do {
                let rowid = try db.run(hks.insert(HK.text_col <- self.text, HK.visible_col <- self.visible,
                                                  HK.note_col <- self.note, HK.keys_col <- self.shortcut))
                self.id = rowid
                setHotKey()
            } catch let Result.error(message, code, statement) where code == SQLITE_CONSTRAINT {
                print("constraint failed: \(message), in \(String(describing: statement))")
            } catch let error {
                print("insertion failed: \(error)")
            }
        }
    }
}
