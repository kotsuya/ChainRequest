//
//  ViewController.swift
//  ChainRequest
//
//  Created by seunghwan.yoo on 2020/05/20.
//  Copyright © 2020 seunghwan.yoo. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class ViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    private let githubRepository = GithubRepository()
    private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.navigationBar.prefersLargeTitles = true
        
        let reposObservable = githubRepository.getRepos().share()
        
        let randomNumber = Int.random(in: 0...50)
        
        reposObservable.map { repos -> String in
            let repo = repos[randomNumber]
            return repo.owner.login + "/" + repo.name
        }
        .startWith("Loding...")
        .bind(to: navigationItem.rx.title)
        .disposed(by: disposeBag)
        
        reposObservable.flatMap { repos -> Observable<[Branch]> in
            let repo = repos[randomNumber]
            return self.githubRepository.getBranches(ownerName: repo.owner.login, repoName: repo.name)
        }
        .bind(to: tableView.rx.items(cellIdentifier: "branchCell", cellType: BranchTableViewCell.self)) { index, branch, cell in
            cell.branchNameLabel.text = branch.name
        }
        .disposed(by: disposeBag)
    }
}

struct Repo: Decodable {
    let name: String
    let owner: Owner
}

struct Owner: Decodable {
    let login: String
}

struct Branch: Decodable {
    let name: String
}

class GithubRepository {
    private let networkService = NetworkService()
    private let baseURLString = "https://api.github.com"
    
    func getRepos() -> Observable<[Repo]> {
        return networkService.execute(url: URL(string: baseURLString + "/repositories")!)
    }
    
    func getBranches(ownerName: String, repoName: String) -> Observable<[Branch]> {
        //GET /repos/:owner/:repo/branches
        return networkService.execute(url: URL(string: baseURLString + "/repos/\(ownerName)/\(repoName)/branches")!)
    }
}

class NetworkService {
    func execute<T: Decodable>(url: URL) -> Observable<T> {
        return Observable.create { observer -> Disposable in
            let task = URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data = data else { return }
                guard let decoded = try? JSONDecoder().decode(T.self, from: data) else { return }
                
                observer.onNext(decoded)
                observer.onCompleted()
            }
            task.resume()
            
            return Disposables.create {
                task.cancel()
            }
        }
    }
}

