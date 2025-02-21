//
//  OnboardingService+Load.swift
//  OnboardingOnline
//
//  Copyright 2023 Onboarding.online on 04.06.2023.
//

import Foundation
import ScreensGraph

public extension OnboardingService {
    
    static func prepareFullOnboardingFor(projectId: String,
                                         localJSONFileName: String,
                                         env: OnboardingEnvironment = .prod,
                                         prefetchMode: OnboardingService.AssetsPrefetchMode = .waitForScreenToLoad(timeout: 0.5),
                                         finishedCallback: @escaping OnboardingPreparationFinishCallback) {
        OnboardingPreparationService.prepareFullOnboardingFor(projectId: projectId,
                                                              localJSONFileName: localJSONFileName,
                                                              env: env,
                                                              prefetchMode: prefetchMode,
                                                              finishedCallback: finishedCallback)
    }
    
    func startPreparedOnboardingWhenReady(projectId: String,
                                          localJSONFileName: String,
                                          env: OnboardingEnvironment = .prod,
                                          useLocalJSONAfterTimeout: TimeInterval,
                                          launchWithAnimation: Bool = false,
                                          finishedCallback: @escaping OnboardingFinishResult) {
        let preparationState = OnboardingPreparationService.onboardingPreparationState(projectId: projectId, env: env)
        
        self.projectId = projectId
        //print("------- onboarding assets loading state \(preparationState)")
        func startNew() {
            startOnboarding(projectId: projectId,
                            localJSONFileName: localJSONFileName,
                            env: env,
                            useLocalJSONAfterTimeout: useLocalJSONAfterTimeout,
                            launchWithAnimation: launchWithAnimation,
                            finishedCallback: finishedCallback)
        }
        
        func startPrepared() {
            OnboardingPreparationService.startPreparedOnboarding(projectId: projectId, env: env, finishedCallback: finishedCallback)
        }
        
        switch preparationState {
        case .notStarted, .failed:
            showLoadingAssetsScreen(appearance: .default,
                                    launchWithAnimation: launchWithAnimation)
            startNew()
        case .preparing:
            let syncQueue = DispatchQueue(label: "com.example.didFinishQueue")
            var didFinish = false
            
            DispatchQueue.global().asyncAfter(deadline: .now() + useLocalJSONAfterTimeout) {
                syncQueue.sync {
                    if !didFinish {
                        didFinish = true
                        mainQueue.async { [weak self] in
                            self?.startOnboardingFrom(localJSONFileName: localJSONFileName, finishedCallback: finishedCallback)
                        }
                    }
                }
            }
            
            showLoadingAssetsScreen(appearance: .default,
                                    launchWithAnimation: launchWithAnimation)
            OnboardingPreparationService.onPreparedWithResult(projectId: projectId, env: env) { result in
                syncQueue.sync {
                    if !didFinish {
                        didFinish = true
                        switch result {
                        case .success:
                            //print("------- onboarding assets downloaded")
                            startPrepared()
                        case .failure:
                            //print("------- onboarding assets loading failed, restart onboarding")
                            startNew()
                        }
                    }
                }
            }
        case .ready:
            startPrepared()
        }
    }
    
    func getPaywall(paywallId: String,
                    projectId: String,
                    localJSONFileName: String,
                    env: OnboardingEnvironment = .prod,
                    useLocalJSONAfterTimeOut: Double,
                    finishedCallback:  @escaping GenericResultCallback<PaywallVC>) {
        
        self.getScreenGraphWhenReady(projectId: projectId, localJSONFileName:localJSONFileName, useLocalJSONAfterTimeOut: useLocalJSONAfterTimeOut) {(result) in
            switch result {
            case .success(let screenGraph):
                let videoService = VideoPreparationService.init(screenGraph: screenGraph)
                if  let screen = screenGraph.screens[paywallId], let screenData = screen.paywallScreenValue(), let paymentService = OnboardingService.shared.paymentService {
                    let paywall = PaywallVC.instantiate(paymentService: paymentService, screen: screen, screenData: screenData, videoPreparationService: videoService)
                    
                    Task { @MainActor in
                            try? await self.prefetchService?.prefetchAssetsFor(screen: screen)
                            finishedCallback(.success(paywall))
                    }
                    
                } else {
                    finishedCallback(.failure(GenericError.init(errorCode: 10, localizedDescription: "Paywall not found")))
                }
                
            case .failure(let error):
                finishedCallback(.failure(GenericError.init(errorCode: 10, localizedDescription: "Paywall not found")))
            }
            
        }
    }
    
    
    func getScreenGraphWhenReady(projectId: String,
                                 localJSONFileName: String,
                                 env: OnboardingEnvironment = .prod,
                                 useLocalJSONAfterTimeOut: Double,
                                 finishedCallback:  @escaping GenericResultCallback<ScreensGraph>) {
        let preparationState = OnboardingPreparationService.onboardingPreparationState(projectId: projectId, env: .prod)
        
        self.projectId = projectId
      
        func getPrepared() {
            if let screenGraph = OnboardingPreparationService.getScreenGraphFor(projectId: projectId) {
                finishedCallback(.success(screenGraph))
            } else {
                finishedCallback(.failure(GenericError.init(errorCode: 5, localizedDescription: "Could not find ScreenGraph")))
            }
        }
        
        switch preparationState {
        case .notStarted, .failed:
            getScreenGraph(projectId: projectId, localJSONFileName: localJSONFileName, useLocalJSONAfterTimeOut: useLocalJSONAfterTimeOut, finishedCallback: finishedCallback)
            print("")
        case .preparing:
            print("")
            OnboardingPreparationService.onPreparedWithResult(projectId: projectId, env: env) { [weak self] result in
                switch result {
                case .success:
                    print("------- onboarding assets downloaded")
                    getPrepared()
                case .failure:
                    self?.getScreenGraph(projectId: projectId, localJSONFileName: localJSONFileName, useLocalJSONAfterTimeOut: useLocalJSONAfterTimeOut, finishedCallback: finishedCallback)
                    print("------- onboarding assets loading failed, restart onboarding")
                }
            }
        case .ready:
            print("")
            getPrepared()
        }
    }
    
    func getScreenGraph(projectId: String, 
                        localJSONFileName: String,
                        env: OnboardingEnvironment = .prod,
                        useLocalJSONAfterTimeOut: Double,
                        finishedCallback: @escaping GenericResultCallback<ScreensGraph>) {
                
        let loadingState = OnboardingLoadingService.LoadingState()

        OnboardingLoadingService.loadScreenGraphFor(projectId: projectId, env: env) { [weak self](result)  in
            switch result {
            case .success(_):
                print("loaded")
                if loadingState.shouldProceedWithLoadedOnboarding() {
                    finishedCallback(result)
                }
            case .failure(let failure):
                do {
                    guard loadingState.shouldProceedWithLoadedOnboarding() else { return }

                    let localPath = try OnboardingLoadingService.getUrlFor(jsonName: localJSONFileName)
                    let localScreenGraph = try OnboardingLoadingService.getOnboardingFromLocalPath(localPath: localPath)
                    finishedCallback(.success(localScreenGraph))

                } catch {
                    finishedCallback(result)
                }
                
                self?.systemEventRegistered(event: .JSONLoadingFailure, params: [.error: failure.localizedDescription])
            }
        }
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + useLocalJSONAfterTimeOut) {
            guard loadingState.shouldProceedWithOnboardingFromLocalPath() else { return }

            do {
                let localPath = try OnboardingLoadingService.getUrlFor(jsonName: localJSONFileName)
                let localScreenGraph = try OnboardingLoadingService.getOnboardingFromLocalPath(localPath: localPath)
                finishedCallback(.success(localScreenGraph))

            } catch {
                finishedCallback(.failure(GenericError.init(errorCode: 25, localizedDescription: "json not found")))
            }
            
        }
    }
    
    
    
    func startOnboarding(projectId: String,
                         localJSONFileName: String,
                         env: OnboardingEnvironment = .prod,
                         useLocalJSONAfterTimeout: TimeInterval,
                         launchWithAnimation: Bool = false,
                         finishedCallback: @escaping OnboardingFinishResult) {
        do {
            let localPath = try OnboardingLoadingService.getUrlFor(jsonName: localJSONFileName)
            let appearance: OnboardingService.AppearanceStyle =  self.appearance ?? .default
            let loadOptions = LoadConfiguration.Options.useLocalAfterTimeout(localPath: localPath,
                                                                             timeout: useLocalJSONAfterTimeout)
            let loadConfiguration = LoadConfiguration.init(projectId: projectId,
                                                           options: loadOptions,
                                                           env: env,
                                                           appearance: appearance,
                                                           launchWithAnimation: launchWithAnimation)
            self.projectId = projectId
            loadOnboarding(configuration: loadConfiguration, finishedCallback: finishedCallback)
        } catch {
            finishedCallback(.failure(.init(error: error)))
        }
    }

    func loadOnboarding(configuration: OnboardingService.LoadConfiguration,
                        finishedCallback: @escaping OnboardingFinishResult) {
        let loadingState = OnboardingLoadingService.LoadingState()
        showLoadingAssetsScreen(appearance: configuration.appearance,
                                launchWithAnimation: configuration.launchWithAnimation)
        
        downloadJSONFromServerAndStartOnboardingIfNotTimedOut(configuration: configuration, 
                                                              loadingState: loadingState, finishedCallback: finishedCallback)
        
        if configuration.needToShowOnboardingFromLocalJson() {
            startOnboardingFromJSON(configuration: configuration,
                                    loadingState: loadingState,
                                    finishedCallback: finishedCallback)
        }
    }
    
    func startOnboardingFrom(localJSONFileName: String,
                             launchWithAnimation: Bool = false,
                             finishedCallback: @escaping OnboardingFinishResult) {
        do {
            let localScreenGraph = try OnboardingLoadingService.getOnboardingFromLocalJsonName(localJSONFileName)
            let config = RunConfiguration.init(screenGraph: localScreenGraph,
                                               appearance: (self.appearance ?? .default),
                                               launchWithAnimation: launchWithAnimation)
            
            OnboardingService.shared.startOnboarding(configuration: config,
                                                     finishedCallback: finishedCallback)
        } catch {
            finishedCallback(.failure(.init(error: error)))
        }
    }
}

// MARK: - Private methods
private extension OnboardingService {
    
    func downloadJSONFromServerAndStartOnboardingIfNotTimedOut(configuration: OnboardingService.LoadConfiguration,
                                                               loadingState: OnboardingLoadingService.LoadingState,
                                                               finishedCallback: @escaping OnboardingFinishResult) {
        let requestStartDate = Date()
        
        OnboardingLoadingService.loadScreenGraphFor(projectId: configuration.projectId, env: configuration.env) { [weak self](result)  in
            switch result {
            case .success(let screenGraph):
                let responseTime = Date().timeIntervalSince(requestStartDate)
                
                if loadingState.shouldProceedWithLoadedOnboarding() {
                    DispatchQueue.main.async {
                        let config = RunConfiguration.init(screenGraph: screenGraph,
                                                           appearance: configuration.appearance,
                                                           launchWithAnimation: configuration.launchWithAnimation)
                        self?.startOnboarding(configuration: config, finishedCallback: finishedCallback)
                        
                        let url = OnboardingLoadingService.buildURL(for: configuration.env)
                        OnboardingLoadingService.registerStartEvent(url: url, responseTime: responseTime, config: config)
                    }
                } else {
                    OnboardingLoadingService.registerJSONLoadedAfterTimeOutEvent(responseTime: responseTime)
                }
                
            case .failure(let failure):
                self?.systemEventRegistered(event: .JSONLoadingFailure, params: [.error: failure.localizedDescription])
            }
        }
    }
    
    func startOnboardingFromJSON(configuration: OnboardingService.LoadConfiguration,
                                 loadingState: OnboardingLoadingService.LoadingState,
                                 finishedCallback: @escaping OnboardingFinishResult) {
        switch configuration.options  {
        case .useLocalAfterTimeout(let localPath, let timeout):
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                guard let strongSelf = self else { return }
                
                do {
                    let localScreenGraph = try OnboardingLoadingService.getOnboardingFromLocalPath(localPath: localPath)
                    guard  loadingState.shouldProceedWithOnboardingFromLocalPath() else { return }
                    OnboardingLoadingService.registerSourceTypeEvent(localPath: localPath, timeout: timeout, screenGraph: localScreenGraph)
                    let config = RunConfiguration.init(screenGraph: localScreenGraph,
                                                       appearance: configuration.appearance,
                                                       launchWithAnimation: configuration.launchWithAnimation)
                    strongSelf.startOnboarding(configuration: config, finishedCallback: finishedCallback)
                } catch {
                    finishedCallback(.failure(.init(error: error)))
                }
            }
        default:
            let error = GenericError.init(errorCode: 2, localizedDescription: "wrong configuration option for locals json using")
            finishedCallback(.failure(error))
        }
    }
}
 
extension OnboardingService.LoadConfiguration {
    
    func needToShowOnboardingFromLocalJson() -> Bool {
        switch self.options {
        case .waitForRemote:
            return false
        default:
            return true
        }
    }
}

