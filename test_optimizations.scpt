-- Test harness for updateNoteData, markDeletedNotes, convertDataToString
-- Run: osascript test_optimizations.scpt

script T
    property passCount : 0
    property failCount : 0

    on ok(name)
        log "PASS: " & name
        set my passCount to my passCount + 1
    end ok

    on fail(name, msg)
        log "FAIL: " & name & " - " & msg
        set my failCount to my failCount + 1
    end fail

    on assert(name, condition)
        if condition then
            my ok(name)
        else
            my fail(name, "condition was false")
        end if
    end assert

    on assertEqual(name, expected, actual)
        if expected = actual then
            my ok(name)
        else
            my fail(name, "expected '" & expected & "' got '" & actual & "'")
        end if
    end assertEqual
end script

-- ---------------------------------------------------------------------------
-- Inline helpers under test (kept in sync with export_notes.scpt)
-- ---------------------------------------------------------------------------

on updateNoteData(existingData, noteID, noteModDate, noteCreatedDate, fileName, fullNoteID)
    set currentTime to (current date as string)
    repeat with i from 1 to count of existingData
        set currentRecord to item i of existingData
        if (noteID_key of currentRecord) = noteID then
            set item i of existingData to {noteID_key:noteID, filename:fileName, created:(noteCreatedDate as string), modified:(noteModDate as string), firstExported:(firstExported of currentRecord), lastExported:currentTime, exportCount:((exportCount of currentRecord) + 1), fullNoteId:fullNoteID}
            return existingData
        end if
    end repeat
    set end of existingData to {noteID_key:noteID, filename:fileName, created:(noteCreatedDate as string), modified:(noteModDate as string), firstExported:currentTime, lastExported:currentTime, exportCount:1, fullNoteId:fullNoteID}
    return existingData
end updateNoteData

on markDeletedNotes(existingData, currentNoteIDs)
    set currentTime to (current date as string)
    set AppleScript's text item delimiters to "|"
    set lookupStr to "|" & (currentNoteIDs as string) & "|"
    set AppleScript's text item delimiters to ""
    repeat with i from 1 to count of existingData
        set currentRecord to item i of existingData
        set recordNoteID to (noteID_key of currentRecord)
        if lookupStr does not contain ("|" & recordNoteID & "|") then
            set alreadyDeleted to false
            try
                set testDeleted to (deletedDate of currentRecord)
                set alreadyDeleted to true
            end try
            if not alreadyDeleted then
                set deletedRecord to {noteID_key:recordNoteID, filename:(filename of currentRecord), created:(created of currentRecord), modified:(modified of currentRecord), firstExported:(firstExported of currentRecord), lastExported:(lastExported of currentRecord), exportCount:(exportCount of currentRecord), deletedDate:currentTime}
                try
                    set deletedRecord to deletedRecord & {fullNoteId:(fullNoteId of currentRecord)}
                end try
                set item i of existingData to deletedRecord
            end if
        end if
    end repeat
    return existingData
end markDeletedNotes

on convertDataToString(dataRecord)
    set parts to {}
    repeat with i from 1 to count of dataRecord
        set currentRecord to item i of dataRecord
        set recordArray to "['" & (noteID_key of currentRecord) & "','" & (filename of currentRecord) & "','" & (created of currentRecord) & "','" & (modified of currentRecord) & "','" & (firstExported of currentRecord) & "','" & (lastExported of currentRecord) & "'," & (exportCount of currentRecord)
        try
            set recordArray to recordArray & ",'" & (deletedDate of currentRecord) & "'"
        on error
            set recordArray to recordArray & ",''"
        end try
        try
            set recordArray to recordArray & ",'" & (fullNoteId of currentRecord) & "']"
        on error
            set recordArray to recordArray & ",'']"
        end try
        set end of parts to recordArray
    end repeat
    set AppleScript's text item delimiters to ","
    set recordString to parts as string
    set AppleScript's text item delimiters to ""
    return recordString
end convertDataToString

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------
set fixedDate to "Wednesday, January 1, 2025 at 12:00:00 AM"
set now to (current date)

set rec1 to {noteID_key:"abc123", filename:"note-one", created:fixedDate, modified:fixedDate, firstExported:fixedDate, lastExported:fixedDate, exportCount:3, fullNoteId:"x://abc123"}
set rec2 to {noteID_key:"def456", filename:"note-two", created:fixedDate, modified:fixedDate, firstExported:fixedDate, lastExported:fixedDate, exportCount:1, fullNoteId:"x://def456"}
set rec3 to {noteID_key:"ghi789", filename:"note-three", created:fixedDate, modified:fixedDate, firstExported:fixedDate, lastExported:fixedDate, exportCount:2, fullNoteId:"x://ghi789"}

-- ---------------------------------------------------------------------------
-- updateNoteData
-- ---------------------------------------------------------------------------
log "--- updateNoteData ---"

set res to my updateNoteData({}, "newid", now, now, "new-note", "x://newid")
T's assert("empty list → count is 1", (count of res) = 1)
T's assertEqual("empty list → exportCount is 1", 1, exportCount of item 1 of res)
T's assert("empty list → firstExported = lastExported", (firstExported of item 1 of res) = (lastExported of item 1 of res))

set existingData to {rec1, rec2}
set res to my updateNoteData(existingData, "newid", now, now, "new-note", "x://newid")
T's assert("new ID → appended (count=3)", (count of res) = 3)
T's assertEqual("new ID → exportCount 1", 1, exportCount of item 3 of res)

set existingData to {rec1, rec2, rec3}
set res to my updateNoteData(existingData, "def456", now, now, "note-two-renamed", "x://def456")
T's assert("existing ID → count unchanged", (count of res) = 3)
T's assertEqual("existing ID → exportCount bumped", 2, exportCount of item 2 of res)
T's assertEqual("existing ID → firstExported preserved", fixedDate, firstExported of item 2 of res)
T's assertEqual("existing ID → filename updated", "note-two-renamed", filename of item 2 of res)
T's assertEqual("other record 1 unchanged", "note-one", filename of item 1 of res)
T's assertEqual("other record 3 unchanged", "note-three", filename of item 3 of res)

-- ---------------------------------------------------------------------------
-- markDeletedNotes
-- ---------------------------------------------------------------------------
log "--- markDeletedNotes ---"

set existingData to {rec1, rec2, rec3}
set res to my markDeletedNotes(existingData, {"abc123", "def456", "ghi789"})
T's assert("all present → count unchanged", (count of res) = 3)
set hasDeleted to false
repeat with r in res
    try
        set d to (deletedDate of r)
        set hasDeleted to true
    end try
end repeat
T's assert("all present → no deletedDate added", not hasDeleted)

set existingData to {rec1, rec2, rec3}
set res to my markDeletedNotes(existingData, {"abc123", "ghi789"})
set gotDeleted to false
try
    set d to (deletedDate of item 2 of res)
    set gotDeleted to true
end try
T's assert("missing note → deletedDate set", gotDeleted)
T's assertEqual("missing note → filename preserved", "note-two", filename of item 2 of res)

set alreadyDeletedRec to {noteID_key:"def456", filename:"note-two", created:fixedDate, modified:fixedDate, firstExported:fixedDate, lastExported:fixedDate, exportCount:1, deletedDate:"old-date", fullNoteId:"x://def456"}
set existingData to {rec1, alreadyDeletedRec, rec3}
set res to my markDeletedNotes(existingData, {"abc123", "ghi789"})
T's assertEqual("already-deleted → deletedDate not overwritten", "old-date", deletedDate of item 2 of res)

set existingData to {rec1, rec2, rec3}
set res to my markDeletedNotes(existingData, {})
set allDeleted to true
repeat with r in res
    set gotD to false
    try
        set d to (deletedDate of r)
        set gotD to true
    end try
    if not gotD then set allDeleted to false
end repeat
T's assert("empty currentNoteIDs → all marked deleted", allDeleted)

-- Prefix/suffix safety: "abc" must not match inside "abcdef"
set recShort to {noteID_key:"abc", filename:"short", created:fixedDate, modified:fixedDate, firstExported:fixedDate, lastExported:fixedDate, exportCount:1, fullNoteId:"x://abc"}
set recLong to {noteID_key:"abcdef", filename:"long", created:fixedDate, modified:fixedDate, firstExported:fixedDate, lastExported:fixedDate, exportCount:1, fullNoteId:"x://abcdef"}
set res to my markDeletedNotes({recShort, recLong}, {"abcdef"})
set shortDeleted to false
try
    set d to (deletedDate of item 1 of res)
    set shortDeleted to true
end try
T's assert("prefix safety → 'abc' marked deleted", shortDeleted)
set longDeleted to false
try
    set d to (deletedDate of item 2 of res)
    set longDeleted to true
end try
T's assert("prefix safety → 'abcdef' not deleted", not longDeleted)

-- ---------------------------------------------------------------------------
-- convertDataToString
-- ---------------------------------------------------------------------------
log "--- convertDataToString ---"

set res to my convertDataToString({})
T's assertEqual("empty list → empty string", "", result)

set res to my convertDataToString({rec1})
T's assert("single record → starts with note ID", res starts with "['abc123'")
T's assert("single record → ends with ]", res ends with "]")
T's assert("single record → no trailing comma after ]", not (result ends with "],"))

set res to my convertDataToString({rec1, rec2, rec3})
set AppleScript's text item delimiters to "],["
set topItems to text items of res
set AppleScript's text item delimiters to ""
T's assert("three records → three items (two ],[ separators)", (count of topItems) = 3)

set recWithDeleted to {noteID_key:"del1", filename:"gone", created:fixedDate, modified:fixedDate, firstExported:fixedDate, lastExported:fixedDate, exportCount:2, deletedDate:"2025-01-15", fullNoteId:"x://del1"}
set res to my convertDataToString({recWithDeleted})
T's assert("record with deletedDate → date in output", res contains "2025-01-15")

set recNoFullID to {noteID_key:"noid1", filename:"no-full-id", created:fixedDate, modified:fixedDate, firstExported:fixedDate, lastExported:fixedDate, exportCount:1}
set res to my convertDataToString({recNoFullID})
T's assert("record without fullNoteId → empty field placeholder", res contains ",'']")

-- ---------------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------------
set total to T's passCount + T's failCount
log "========================="
log "Tests: " & (T's passCount) & "/" & total
if T's failCount > 0 then
    error "Test suite failed: " & (T's failCount) & " failure(s)"
end if
