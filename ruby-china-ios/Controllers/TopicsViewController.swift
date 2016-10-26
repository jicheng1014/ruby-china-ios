//
//  TopicsTableViewController.swift
//  ruby-china-ios
//
//  Created by 柯磊 on 16/10/13.
//  Copyright © 2016年 ruby-china. All rights reserved.
//

import UIKit
import UITableView_FDTemplateLayoutCell

class TopicsViewController: UITableViewController {

    private let kCellReuseIdentifier = "TOPIC_CELL"
    
    private var isLoading = false
    private var listType = TopicsService.ListType.popular
    private var nodeID = 0
    private var topicList: [Topic]?
    
    private var errorView: ErrorView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        clearsSelectionOnViewWillAppear = true
        
        tableView.registerClass(TopicCell.self, forCellReuseIdentifier: kCellReuseIdentifier)
        tableView.separatorColor = UIColor(white: 0.94, alpha: 1)
        tableView.tableFooterView = UIView()
        tableView.separatorInset = UIEdgeInsetsZero
        tableView.headerWithRefreshingBlock { [weak self] in
            self?.errorView?.removeFromSuperview()
            self?.load(offset: 0)
        }
        tableView.footerWithRefreshingBlock { [weak self] in
            guard let `self` = self else {
                return
            }
            self.load(offset: self.topicList!.count)
        }
        
        if (nodeID > 0) {
            loadNodeInfo()
        }
    }

    // MARK: - Table view data source

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return topicList == nil ? 0 : topicList!.count
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let data = topicList![indexPath.row]
        return tableView.fd_heightForCellWithIdentifier(kCellReuseIdentifier, configuration: { (cell) in
            if let cell = cell as? TopicCell {
                cell.data = data
            }
        })
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(kCellReuseIdentifier, forIndexPath: indexPath) as! TopicCell
        cell.data = topicList![indexPath.row]
        cell.onUserClick = { (data) in
            guard let topic = data else {
                return
            }
            TurbolinksSessionLib.sharedInstance.actionToPath("/\(topic.user.login)", withAction: .Advance)
        }
        cell.onNodeClick = { [weak self] (data) in
            guard let `self` = self, topic = data else {
                return
            }
            
            if (self.nodeID > 0) {
                // 已经在节点帖子列表界面，再点击节点，则不再打开节点帖子界面，而直接进入帖子
                TurbolinksSessionLib.sharedInstance.actionToPath("/topics/\(topic.id)", withAction: .Advance)
            } else {
                TurbolinksSessionLib.sharedInstance.actionToPath("/topics/node\(topic.nodeID)", withAction: .Advance)
            }
        }
        return cell
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let data = topicList![indexPath.row]
        TurbolinksSessionLib.sharedInstance.actionToPath("/topics/\(data.id)", withAction: .Advance)
    }
    
}

// MARK: - public

extension TopicsViewController {
    
    func load(listType listType: TopicsService.ListType, nodeID: Int, offset: Int) {
        self.listType = listType
        self.nodeID = nodeID
        self.tableView.mj_header.beginRefreshing()
    }
    
}

// MARK: - private

extension TopicsViewController {
    
    private func load(offset offset: Int) {
        if isLoading { return }
        isLoading = true
        
        let limit = 40
        TopicsService.list(listType, node_id: nodeID, offset: offset, limit: limit, callback: { [weak self] (response, result) in
            guard let `self` = self else {
                return
            }
            self.isLoading = false
            
            if (self.tableView.mj_header.isRefreshing()) {
                self.tableView.mj_header.endRefreshing()
            }
            if (self.tableView.mj_footer.isRefreshing()) {
                self.tableView.mj_footer.endRefreshing()
            }
            self.tableView.mj_footer.hidden = result == nil ? true : (result!.count < limit)
            
            if let topics = result {
                if self.topicList == nil || offset == 0 {
                    self.topicList = topics
                } else {
                    self.topicList! += topics
                }
                self.tableView.reloadData()
            } else {
                var error: Error!
                switch response.result {
                case .Success:
                    guard let statusCode = response.response?.statusCode else {
                        return
                    }
                    switch statusCode {
                    case 404:
                        error = Error.HTTPNotFoundError
                    default:
                        error = Error(HTTPStatusCode: statusCode)
                    }
                case .Failure(let err):
                    error = Error(title: "网络连接错误", message: err.localizedDescription)
                }
                
                if let list = self.topicList where list.count > 0 {
                    RBHUD.error(error.message)
                } else {
                    self.presentError(error)
                }
            }
        })
    }
    
    private func presentError(error: Error) {
        errorView?.removeFromSuperview()
        
        errorView = NSBundle.mainBundle().loadNibNamed("ErrorView", owner: self, options: nil)!.first as? ErrorView
        if errorView == nil {
            return
        }
        
        errorView!.retryButton.addTarget(self, action: #selector(errorViewRetryAction), forControlEvents: .TouchUpInside)
        errorView!.error = error
        view.addSubview(errorView!)
        errorView!.snp_remakeConstraints { (make) in
            make.edges.equalToSuperview()
            var screenSize = UIScreen.mainScreen().bounds.size
            screenSize.height -= 64 + 49
            make.size.equalTo(screenSize)
        }
    }
    
    func errorViewRetryAction() {
        tableView.mj_header.beginRefreshing()
    }
    
    private func loadNodeInfo() {
        NodesService.info(nodeID) { [weak self] (statusCode, result) in
            self?.title = result == nil ? "title node".localized : result!.name;
        }
    }
}
