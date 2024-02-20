//
//  ChatThreadParticipantsController.swift
//  EaseChatUIKit
//
//  Created by 朱继超 on 2024/1/24.
//

import UIKit

@objcMembers open class ChatThreadParticipantsController: UIViewController {
    
    private var cursor = ""
        
    private var pageSize = 20
    
    public private(set) var profile = GroupChatThread()
    /**
     The array of participants in the group.
     */
    public private(set) var participants: [EaseProfileProtocol] = []
    
    public private(set) lazy var navigation: EaseChatNavigationBar = {
        self.createNavigation()
    }()
    
    /// Creates and returns a navigation bar for the ChatThreadParticipantsController.
    /// - Returns: An instance of EaseChatNavigationBar.
    @objc open func createNavigation() -> EaseChatNavigationBar {
        EaseChatNavigationBar(frame: CGRect(x: 0, y: 0, width: ScreenWidth, height: NavigationHeight),showLeftItem: true, textAlignment: .left ,hiddenAvatar: true).backgroundColor(.clear)
    }

    
    public private(set) lazy var participantsList: UITableView = {
        UITableView(frame: CGRect(x: 0, y: self.navigation.frame.height, width: self.view.frame.width, height: self.view.frame.height-self.navigation.frame.height), style: .plain).delegate(self).dataSource(self).tableFooterView(UIView()).rowHeight(60).backgroundColor(.clear).separatorStyle(.none)
    }()
    
    public required init(chatThread: GroupChatThread) {
        self.profile = chatThread
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubViews([self.navigation,self.participantsList])
        self.navigation.title = "topic_members".chat.localize
        // Do any additional setup after loading the view.
        //click of the navigation
        self.navigation.clickClosure = { [weak self] in
            self?.navigationClick(type: $0, indexPath: $1)
        }
        self.fetchParticipants()
        
        Theme.registerSwitchThemeViews(view: self)
        self.switchTheme(style: Theme.style)
        // Do any additional setup after loading the view.
    }
    
    /**
     Handles the navigation bar click events.
     
     - Parameters:
        - type: The type of navigation bar click event.
        - indexPath: The index path associated with the event (optional).
     */
    @objc open func navigationClick(type: EaseChatNavigationBarClickEvent, indexPath: IndexPath?) {
        switch type {
        case .back: self.pop()
        default:
            break
        }
    }
    
    @objc open func pop() {
        if self.navigationController != nil {
            self.navigationController?.popViewController(animated: true)
        } else {
            self.dismiss(animated: true)
        }
    }

    open func fetchParticipants() {
        ChatClient.shared().threadManager?.getChatThreadMemberListFromServer(withId: self.profile.threadId, cursor: self.cursor, pageSize: self.pageSize, completion: { [weak self] result, error in
            guard let `self` = self else { return }
            if error == nil {
                if let list = result?.list {
                    if self.cursor.isEmpty {
                        self.participants.removeAll()
                        self.participants = list.map({
                            let profile = EaseProfile()
                            profile.id = $0 as String
                            profile.nickname = $0 as String
                            return profile
                        })
                    } else {
                        self.participants.append(contentsOf: list.map({
                            let profile = EaseProfile()
                            profile.id = $0 as String
                            return profile
                        }))
                    }
                }
                self.cursor = result?.cursor ?? ""
                self.participantsList.reloadData()
            } else {
                consoleLogInfo("GroupParticipantsController fetch error:\(error?.errorDescription ?? "")", type: .error)
            }
        })
    }
}

extension ChatThreadParticipantsController: UITableViewDelegate,UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.participants.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        self.cellForRowAt(indexPath: indexPath)
    }
    
    @objc open func cellForRowAt(indexPath: IndexPath) -> UITableViewCell {
        var cell = self.participantsList.dequeueReusableCell(withIdentifier: "GroupParticipantCell") as? GroupParticipantCell
        if cell == nil {
            cell = GroupParticipantCell(displayStyle: .normal, identifier: "GroupParticipantCell")
        }
        if let profile = self.participants[safe: indexPath.row] {
            cell?.refresh(profile: profile, keyword: "")
        }
        cell?.selectionStyle = .none
        return cell ?? GroupParticipantCell()
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        var unknownInfoIds = [String]()
        if let visiblePaths = self.participantsList.indexPathsForVisibleRows {
            for indexPath in visiblePaths {
                if let nickName = self.participants[safe: indexPath.row]?.nickname,nickName.isEmpty {
                    unknownInfoIds.append(self.participants[safe: indexPath.row]?.id ?? "")
                }
            }
        }
        if !unknownInfoIds.isEmpty {
            if EaseChatUIKitContext.shared?.groupMemberAttributeCache?.provider == nil,EaseChatUIKitContext.shared?.groupMemberAttributeCache?.providerOC == nil {
                EaseChatUIKitContext.shared?.groupMemberAttributeCache?.fetchCacheValue(groupId: self.profile.parentId, userIds: unknownInfoIds, key: "nickName") { [weak self] error, values in
                    if error == nil,let values = values {
                        self?.processCacheInfos(values: values)
                    }
                }
            } else {
                if EaseChatUIKitContext.shared?.groupMemberAttributeCache?.provider != nil {
                    self.processCacheProfiles(values: EaseChatUIKitContext.shared?.groupMemberAttributeCache?.fetchCacheProfile(groupId: self.profile.parentId, userIds: unknownInfoIds) ?? [])
                } else {
                    EaseChatUIKitContext.shared?.groupMemberAttributeCache?.fetchCacheProfileOC(groupId: self.profile.parentId, userIds: unknownInfoIds) { [weak self] profiles in
                        self?.processCacheProfiles(values: profiles)
                    }
                }
            }
        }
    }
    
    private func processCacheInfos(values: [String]) {
        for participant in self.participants {
            for value in values {
                if value == participant.id {
                    participant.nickname = value
                }
            }
        }
        self.participantsList.reloadData()
    }
    
    private func processCacheProfiles(values: [EaseProfileProtocol]) {
        for participant in self.participants {
            for value in values {
                if value.id == participant.id {
                    participant.nickname = value.nickname
                    participant.avatarURL = value.avatarURL
                }
            }
        }
        self.participantsList.reloadData()
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        DialogManager.shared.showActions(actions: [ActionSheetItem(title: "Remove Member", type: .destructive, tag: "RemoveMember")]) { [weak self] item in
            if item.tag == "RemoveMember" {
                self?.removeMember(user: self?.participants[safe: indexPath.row] ?? EaseProfile())
            }
        }
    }
                                                   
    open func removeMember(user: EaseProfileProtocol) {
        ChatClient.shared().threadManager?.removeMember(fromChatThread: user.id, threadId: self.profile.threadId, completion: { error in
            if error == nil {
                self.participants.removeAll(where: { $0.id == user.id })
                self.participantsList.reloadData()
            } else {
                consoleLogInfo("GroupParticipantsController remove error:\(error?.errorDescription ?? "")", type: .error)
            }
        })
    }
    
    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row >= self.participants.count-3,self.cursor.isEmpty {
            self.fetchParticipants()
        }
    }
}

extension ChatThreadParticipantsController: ThemeSwitchProtocol {
    open func switchTheme(style: ThemeStyle) {
        self.view.backgroundColor = style == .dark ? UIColor.theme.neutralColor1:UIColor.theme.neutralColor98
    }
}
