# Fix Xcode File References

The compilation errors you're seeing are because the Swift files exist on disk but aren't added to the Xcode project target. Here's how to fix it:

## Files to Add to Xcode Project

These files need to be added to the SoccerX target:

### Group Views (already exist on disk):
- `/Users/furkan/SoccerX/iOS/SoccerX/Views/Groups/CreateGroupView.swift`
- `/Users/furkan/SoccerX/iOS/SoccerX/Views/Groups/JoinGroupView.swift`

## Steps to Fix in Xcode:

1. **Open Xcode Project**
   - Open `SoccerX.xcodeproj` in Xcode

2. **Add Missing Files**
   - Right-click on the `Groups` folder in the project navigator
   - Select "Add Files to 'SoccerX'..."
   - Navigate to `/Users/furkan/SoccerX/iOS/SoccerX/Views/Groups/`
   - Select both `CreateGroupView.swift` and `JoinGroupView.swift`
   - Make sure "Copy items if needed" is UNCHECKED (files already exist)
   - Make sure "Add to targets: SoccerX" is CHECKED
   - Click "Add"

3. **Verify Target Membership**
   - Select each file in the project navigator
   - Open the File Inspector (right panel)
   - Under "Target Membership", ensure "SoccerX" is checked

4. **Clean and Build**
   - Product → Clean Build Folder (⇧⌘K)
   - Product → Build (⌘B)

## Alternative: Command Line Fix

If you prefer using the command line, you can use this Ruby script with the xcodeproj gem:

```ruby
require 'xcodeproj'

project_path = '/Users/furkan/SoccerX/iOS/SoccerX.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the Groups group
groups_group = project.main_group.find_subpath('SoccerX/Views/Groups')

# Add files if they don't exist in project
files_to_add = ['CreateGroupView.swift', 'JoinGroupView.swift']

files_to_add.each do |filename|
  file_path = "/Users/furkan/SoccerX/iOS/SoccerX/Views/Groups/#{filename}"
  
  # Check if file already exists in project
  existing = groups_group.files.find { |f| f.name == filename }
  
  unless existing
    file_ref = groups_group.new_file(file_path)
    
    # Add to main target
    main_target = project.targets.find { |t| t.name == 'SoccerX' }
    main_target.add_file_references([file_ref])
  end
end

project.save
```

## Verification

After adding the files, you should see:
- ✓ No more "Cannot find 'CreateGroupView' in scope" errors
- ✓ No more "Cannot find 'JoinGroupView' in scope" errors
- ✓ The app builds successfully

## Note
This is a common issue when files are created outside of Xcode. Always ensure new files are properly added to the Xcode project and the correct target.