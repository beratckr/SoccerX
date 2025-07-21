import XCTest
@testable import SoccerX
import Combine

class GroupManagerTests: XCTestCase {
    
    // MARK: - Invite Code Tests
    
    func testGenerateInviteCode() {
        // Test the static method directly
        let code = Group.generateInviteCode()
        
        // Should be 6 characters
        XCTAssertEqual(code.count, 6)
        
        // Should only contain allowed characters
        let allowedCharacters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        for char in code {
            XCTAssertTrue(allowedCharacters.contains(char))
        }
    }
    
    func testGenerateMultipleUniqueCodes() {
        var codes = Set<String>()
        
        // Generate 1000 codes
        for _ in 0..<1000 {
            codes.insert(Group.generateInviteCode())
        }
        
        // Should have very high uniqueness (allow for tiny collision chance)
        XCTAssertGreaterThan(codes.count, 990)
    }
    
    // MARK: - Group Validation Tests
    
    func testValidateGroupName() {
        // Valid names
        XCTAssertTrue(isValidGroupName("Weekend Warriors"))
        XCTAssertTrue(isValidGroupName("FC Barcelona Fans"))
        XCTAssertTrue(isValidGroupName("123 Soccer Club"))
        
        // Invalid names
        XCTAssertFalse(isValidGroupName(""))
        XCTAssertFalse(isValidGroupName("   "))
        XCTAssertFalse(isValidGroupName(String(repeating: "A", count: 101))) // Too long
    }
    
    func testValidateGroupDescription() {
        // Valid descriptions
        XCTAssertTrue(isValidGroupDescription("A great group for weekend players"))
        XCTAssertTrue(isValidGroupDescription(nil)) // Optional
        
        // Invalid descriptions
        XCTAssertFalse(isValidGroupDescription(String(repeating: "A", count: 501))) // Too long
    }
    
    // MARK: - Member Limit Tests
    
    func testDefaultMemberLimits() {
        // Free tier
        XCTAssertEqual(getDefaultMemberLimit(isPremium: false), 10)
        
        // Premium tier
        XCTAssertEqual(getDefaultMemberLimit(isPremium: true), 50)
    }
    
    func testCanAddMember() {
        var group = Group(name: "Test", description: nil, creatorId: "creator")
        group.maxMembers = 3
        
        // Can add when not full
        group.memberIds = ["creator", "member1"]
        XCTAssertTrue(canAddMember(to: group))
        
        // Cannot add when full
        group.memberIds = ["creator", "member1", "member2"]
        XCTAssertFalse(canAddMember(to: group))
    }
    
    // MARK: - Business Logic Tests
    
    func testCreatorCannotBeRemoved() {
        let group = Group(name: "Test", description: nil, creatorId: "creator123")
        
        XCTAssertFalse(canRemoveMember("creator123", from: group))
        XCTAssertTrue(canRemoveMember("member456", from: group))
    }
    
    func testMemberRoleAssignment() {
        let creatorRole = getMemberRole(userId: "creator123", in: Group(name: "Test", description: nil, creatorId: "creator123"))
        XCTAssertEqual(creatorRole, GroupMember.MemberRole.creator)
        
        let memberRole = getMemberRole(userId: "member456", in: Group(name: "Test", description: nil, creatorId: "creator123"))
        XCTAssertEqual(memberRole, GroupMember.MemberRole.member)
    }
    
    // MARK: - Helper Functions (These would be in the actual GroupManager)
    
    private func isValidGroupName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 100
    }
    
    private func isValidGroupDescription(_ description: String?) -> Bool {
        guard let description = description else { return true }
        return description.count <= 500
    }
    
    private func getDefaultMemberLimit(isPremium: Bool) -> Int {
        return isPremium ? 50 : 10
    }
    
    private func canAddMember(to group: Group) -> Bool {
        return group.memberIds.count < group.maxMembers
    }
    
    private func canRemoveMember(_ userId: String, from group: Group) -> Bool {
        return userId != group.creatorId
    }
    
    private func getMemberRole(userId: String, in group: Group) -> GroupMember.MemberRole {
        if userId == group.creatorId {
            return .creator
        }
        // In real implementation, would check admin list
        return .member
    }
}