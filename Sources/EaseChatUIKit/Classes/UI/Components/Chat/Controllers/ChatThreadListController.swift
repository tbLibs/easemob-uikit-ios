//
//  ChatThreadListController.swift
//  EaseChatUIKit
//
//  Created by 朱继超 on 2024/1/24.
//

import UIKit

@objcMembers open class ChatThreadListController: UIViewController {
    
    public private(set) var threads = [GroupChatThread]() {
        didSet {
            DispatchQueue.main.async {
                if self.threads.count <= 0 {
                    self.topicList.backgroundView = self.empty
                } else {
                    self.topicList.backgroundView = nil
                }
            }
        }
    }
    
    private var cursor = ""
    
    private let pageSize = 20
    
    public private(set) var groupId = ""
    
    public private(set) lazy var navigation: EaseChatNavigationBar = {
        EaseChatNavigationBar(showLeftItem: true,textAlignment: .left,hiddenAvatar: true).backgroundColor(.white)
    }()
    
    public private(set) lazy var empty: EmptyStateView = {
        EmptyStateView(frame: self.topicList.bounds,emptyImage: UIImage(named: "empty",in: .chatBundle, with: nil), onRetry: { [weak self] in

        }).backgroundColor(.clear)
    }()
    
    public private(set) lazy var topicList: UITableView = {
        UITableView(frame: CGRect(x: 0, y: NavigationHeight, width: self.view.frame.width, height: ScreenHeight-NavigationHeight), style: .plain).delegate(self).dataSource(self).tableFooterView(UIView()).rowHeight(60).separatorStyle(.none).showsVerticalScrollIndicator(false).tableFooterView(UIView()).backgroundColor(.clear)
    }()
    
    public required init(groupId: String) {
        self.groupId = groupId
        super.init(nibName: nil, bundle: nil)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubViews([self.navigation,self.topicList])
        self.navigation.title = "All Threads"
        // Do any additional setup after loading the view.
        self.requestThreadList()
        self.switchTheme(style: Theme.style)
        self.navigation.clickClosure = { [weak self] in
            self?.navigationClick(type: $0, indexPath: $1)
        }
    }
    
    open func requestThreadList() {
        ChatClient.shared().threadManager?.getJoinedChatThreadsFromServer(withParentId: self.groupId, cursor: self.cursor, pageSize: self.pageSize, completion: { [weak self] result, error in
            guard let `self` = self else { return }
            if error == nil {
                self.cursor = result?.cursor ?? ""
                if let threads = result?.list {
                    self.threads.append(contentsOf: threads)
                } else {
                    self.threads = []
                }
            } else {
                self.topicList.backgroundView = self.empty
                consoleLogInfo("requestThreadList error:\(error?.errorDescription ?? "")", type: .debug)
            }
            self.topicList.reloadData()
        })
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
}

extension ChatThreadListController: UITableViewDelegate,UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.threads.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "ChatThreadCell") as? ChatThreadCell
        if cell == nil {
            cell = ChatThreadCell(style: .default, reuseIdentifier: "ChatThreadCell")
        }
        if let thread = self.threads[safe: indexPath.row] {
            cell?.refresh(chatThread: thread)
        }
        cell?.selectionStyle = .none
        return cell ?? UITableViewCell()
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let thread = self.threads[safe: indexPath.row] {
            let vc = ChatThreadViewController(chatThread: thread,parentMessageId: thread.messageId)
            ControllerStack.toDestination(vc: vc)
        }
    }
}

//MARK: - ThemeSwitchProtocol
extension ChatThreadListController: ThemeSwitchProtocol {
    
    public func switchTheme(style: ThemeStyle) {
        self.navigation.backgroundColor = style == .dark ? UIColor.theme.neutralColor1:UIColor.theme.neutralColor98
        self.view.backgroundColor = style == .dark ? UIColor.theme.neutralColor1:UIColor.theme.neutralColor98
    }
    
}
