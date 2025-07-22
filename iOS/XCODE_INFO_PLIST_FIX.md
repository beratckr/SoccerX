# Fix for "Multiple commands produce Info.plist" Error

## Quick Solution

1. **Clean Build Folder**
   - In Xcode: `Product → Clean Build Folder` (or `Cmd+Shift+K`)

2. **Delete Derived Data**
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/SoccerX-*
   ```

3. **Restart Xcode**

## Detailed Fix Steps

### 1. Check Build Settings
1. Select the `SoccerW Watch App` target in Xcode
2. Go to `Build Settings` tab
3. Search for "Info.plist File"
4. Ensure it's set to: `SoccerW Watch App/Info.plist`
5. Make sure there's only ONE entry

### 2. Check Build Phases
1. Select the `SoccerW Watch App` target
2. Go to `Build Phases` tab
3. Expand `Copy Bundle Resources`
4. Look for `Info.plist` - if it's there, remove it (Info.plist should NOT be in Copy Bundle Resources)
5. Check `Compile Sources` - Info.plist should NOT be here either

### 3. Check for Duplicate Targets
1. In the project navigator, ensure there's only one `SoccerW Watch App` target
2. Check that the Watch app target doesn't have duplicate build phases

### 4. Verify Info.plist Processing
1. In Build Settings, search for "Info.plist"
2. Check these settings:
   - `Info.plist File`: `SoccerW Watch App/Info.plist`
   - `Expand Build Settings in Info.plist`: `YES`
   - `Info.plist Preprocessor Prefix File`: (should be empty or project-specific)

### 5. Check for Script Phases
1. In Build Phases, check if there are any "Run Script" phases that might be copying Info.plist
2. Remove or fix any scripts that duplicate Info.plist processing

## If Issue Persists

### Option 1: Remove and Re-add Info.plist
1. Remove Info.plist reference from Xcode (keep the file)
2. Add it back: Right-click on `SoccerW Watch App` folder → Add Files → Select Info.plist
3. Make sure "Copy items if needed" is UNCHECKED
4. Select the correct target membership

### Option 2: Create New Info.plist
1. Rename current Info.plist to Info.plist.backup
2. In Xcode: File → New → File → Resource → Property List
3. Name it Info.plist and save in `SoccerW Watch App` folder
4. Copy content from backup file

### Option 3: Check Project File
Look for duplicate entries in `project.pbxproj`:
```bash
grep -n "Info.plist" SoccerX.xcodeproj/project.pbxproj | grep -i "watch"
```

## Prevention
- Always use Xcode's UI to manage Info.plist
- Don't manually add Info.plist to Copy Bundle Resources
- Keep only one Info.plist per target