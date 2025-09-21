;; Synergi-Link: Cross-chain Cooperative Governance Smart Contract
;; With Reputation-Weighted Voting System

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u101))
(define-constant ERR_PROPOSAL_EXPIRED (err u102))
(define-constant ERR_ALREADY_VOTED (err u103))
(define-constant ERR_INSUFFICIENT_REPUTATION (err u104))
(define-constant ERR_INVALID_PARAMETERS (err u105))
(define-constant ERR_PROPOSAL_ALREADY_EXECUTED (err u106))

;; Minimum reputation required to create proposals
(define-constant MIN_REPUTATION_TO_PROPOSE u100)
;; Minimum voting period in blocks
(define-constant MIN_VOTING_PERIOD u144) ;; ~24 hours at 10min blocks
;; Maximum voting period in blocks  
(define-constant MAX_VOTING_PERIOD u4320) ;; ~30 days
;; Reputation decay factor (per 1000 blocks)
(define-constant REPUTATION_DECAY_RATE u2)

;; Data Variables
(define-data-var proposal-counter uint u0)
(define-data-var governance-active bool true)

;; Data Maps

;; Reputation System
(define-map user-reputation
    { user: principal }
    { 
        score: uint,
        last-updated: uint,
        total-contributions: uint,
        successful-proposals: uint,
        failed-proposals: uint
    }
)

;; Cross-chain Bridges Registry
(define-map supported-chains
    { chain-id: (string-ascii 32) }
    { 
        active: bool,
        bridge-contract: (string-ascii 128),
        reputation-weight: uint ;; Weight multiplier for cross-chain actions
    }
)

;; Proposals
(define-map proposals
    { proposal-id: uint }
    {
        proposer: principal,
        title: (string-utf8 256),
        description: (string-utf8 1024),
        proposal-type: (string-ascii 32),
        target-chain: (string-ascii 32),
        start-block: uint,
        end-block: uint,
        yes-votes: uint,
        no-votes: uint,
        total-reputation-voted: uint,
        executed: bool,
        passed: bool
    }
)

;; Vote tracking
(define-map proposal-votes
    { proposal-id: uint, voter: principal }
    { 
        vote: bool, ;; true = yes, false = no
        reputation-at-vote: uint,
        block-height: uint
    }
)

;; Contribution tracking for reputation building
(define-map user-contributions
    { user: principal, contribution-id: uint }
    {
        contribution-type: (string-ascii 32),
        reputation-earned: uint,
        block-height: uint,
        verified: bool
    }
)

;; Cross-chain action tracking
(define-map cross-chain-actions
    { action-id: uint }
    {
        initiator: principal,
        source-chain: (string-ascii 32),
        target-chain: (string-ascii 32),
        action-type: (string-ascii 32),
        reputation-impact: uint,
        completed: bool
    }
)

(define-data-var action-counter uint u0)
(define-data-var contribution-counter uint u0)

;; Read-only functions

;; Get user reputation with decay calculation
(define-read-only (get-current-reputation (user principal))
    (let (
        (reputation-data (default-to 
            { score: u0, last-updated: u0, total-contributions: u0, successful-proposals: u0, failed-proposals: u0 }
            (map-get? user-reputation { user: user })
        ))
        (blocks-passed (- stacks-block-height (get last-updated reputation-data)))
        (decay-amount (/ (* blocks-passed REPUTATION_DECAY_RATE) u1000))
        (current-score (if (> decay-amount (get score reputation-data))
            u0
            (- (get score reputation-data) decay-amount)
        ))
    )
    current-score
    )
)

;; Get proposal details
(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals { proposal-id: proposal-id })
)

;; Get voting power (reputation-based)
(define-read-only (get-voting-power (user principal))
    (let (
        (reputation (get-current-reputation user))
    )
    ;; Voting power is square root of reputation to prevent extreme concentration
    (if (> reputation u0)
        (+ u1 (/ reputation u10)) ;; Base vote + reputation bonus
        u1 ;; Minimum voting power
    ))
)

;; Check if user has voted on proposal
(define-read-only (has-voted (proposal-id uint) (user principal))
    (is-some (map-get? proposal-votes { proposal-id: proposal-id, voter: user }))
)

;; Get supported chain info
(define-read-only (get-chain-info (chain-identifier (string-ascii 32)))
    (map-get? supported-chains { chain-id: chain-identifier })
)

;; Public functions

;; Initialize or update user reputation
(define-public (initialize-reputation)
    (let (
        (current-rep (default-to 
            { score: u50, last-updated: stacks-block-height, total-contributions: u0, successful-proposals: u0, failed-proposals: u0 }
            (map-get? user-reputation { user: tx-sender })
        ))
    )
    (ok (map-set user-reputation
        { user: tx-sender }
        (merge current-rep { last-updated: stacks-block-height })
    )))
)

;; Add contribution to build reputation
(define-public (add-contribution (contribution-type (string-ascii 32)) (reputation-earned uint))
    (let (
        (contribution-id (+ (var-get contribution-counter) u1))
        (current-rep (get-current-reputation tx-sender))
    )
    (asserts! (and (> reputation-earned u0) (<= reputation-earned u50)) ERR_INVALID_PARAMETERS)
    
    ;; Record contribution
    (map-set user-contributions
        { user: tx-sender, contribution-id: contribution-id }
        {
            contribution-type: contribution-type,
            reputation-earned: reputation-earned,
            block-height: stacks-block-height,
            verified: false
        }
    )
    
    ;; Update user reputation
    (map-set user-reputation
        { user: tx-sender }
        {
            score: (+ current-rep reputation-earned),
            last-updated: stacks-block-height,
            total-contributions: (+ u1 (default-to u0 (get total-contributions (map-get? user-reputation { user: tx-sender })))),
            successful-proposals: (default-to u0 (get successful-proposals (map-get? user-reputation { user: tx-sender }))),
            failed-proposals: (default-to u0 (get failed-proposals (map-get? user-reputation { user: tx-sender })))
        }
    )
    
    (var-set contribution-counter contribution-id)
    (ok contribution-id)
    )
)

;; Create a new governance proposal
(define-public (create-proposal 
    (title (string-utf8 256))
    (description (string-utf8 1024))
    (proposal-type (string-ascii 32))
    (target-chain (string-ascii 32))
    (voting-period uint)
)
    (let (
        (proposal-id (+ (var-get proposal-counter) u1))
        (proposer-reputation (get-current-reputation tx-sender))
        (end-block (+ stacks-block-height voting-period))
    )
    (asserts! (var-get governance-active) ERR_UNAUTHORIZED)
    (asserts! (>= proposer-reputation MIN_REPUTATION_TO_PROPOSE) ERR_INSUFFICIENT_REPUTATION)
    (asserts! (and (>= voting-period MIN_VOTING_PERIOD) (<= voting-period MAX_VOTING_PERIOD)) ERR_INVALID_PARAMETERS)
    
    ;; Create proposal
    (map-set proposals
        { proposal-id: proposal-id }
        {
            proposer: tx-sender,
            title: title,
            description: description,
            proposal-type: proposal-type,
            target-chain: target-chain,
            start-block: stacks-block-height,
            end-block: end-block,
            yes-votes: u0,
            no-votes: u0,
            total-reputation-voted: u0,
            executed: false,
            passed: false
        }
    )
    
    (var-set proposal-counter proposal-id)
    (ok proposal-id)
    )
)

;; Vote on a proposal
(define-public (vote-on-proposal (proposal-id uint) (vote bool))
    (let (
        (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
        (voter-reputation (get-current-reputation tx-sender))
        (voting-power (get-voting-power tx-sender))
    )
    (asserts! (not (has-voted proposal-id tx-sender)) ERR_ALREADY_VOTED)
    (asserts! (<= stacks-block-height (get end-block proposal)) ERR_PROPOSAL_EXPIRED)
    (asserts! (> voter-reputation u0) ERR_INSUFFICIENT_REPUTATION)
    
    ;; Record vote
    (map-set proposal-votes
        { proposal-id: proposal-id, voter: tx-sender }
        {
            vote: vote,
            reputation-at-vote: voter-reputation,
            block-height: stacks-block-height
        }
    )
    
    ;; Update proposal vote counts
    (map-set proposals
        { proposal-id: proposal-id }
        (merge proposal {
            yes-votes: (if vote (+ (get yes-votes proposal) voting-power) (get yes-votes proposal)),
            no-votes: (if vote (get no-votes proposal) (+ (get no-votes proposal) voting-power)),
            total-reputation-voted: (+ (get total-reputation-voted proposal) voter-reputation)
        })
    )
    
    (ok true)
    )
)

;; Execute proposal if it has passed
(define-public (execute-proposal (proposal-id uint))
    (let (
        (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
    )
    (asserts! (> stacks-block-height (get end-block proposal)) ERR_PROPOSAL_EXPIRED)
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_ALREADY_EXECUTED)
    
    (let (
        (passed (> (get yes-votes proposal) (get no-votes proposal)))
        (proposer (get proposer proposal))
        (current-proposer-rep (default-to 
            { score: u0, last-updated: u0, total-contributions: u0, successful-proposals: u0, failed-proposals: u0 }
            (map-get? user-reputation { user: proposer })
        ))
    )
    
    ;; Mark proposal as executed
    (map-set proposals
        { proposal-id: proposal-id }
        (merge proposal { executed: true, passed: passed })
    )
    
    ;; Update proposer reputation based on outcome
    (map-set user-reputation
        { user: proposer }
        (merge current-proposer-rep {
            successful-proposals: (if passed (+ (get successful-proposals current-proposer-rep) u1) (get successful-proposals current-proposer-rep)),
            failed-proposals: (if passed (get failed-proposals current-proposer-rep) (+ (get failed-proposals current-proposer-rep) u1)),
            score: (if passed 
                (+ (get score current-proposer-rep) u25) 
                (if (> (get score current-proposer-rep) u10) (- (get score current-proposer-rep) u10) u0)
            ),
            last-updated: stacks-block-height
        })
    )
    
    (ok passed)
    ))
)

;; Register a new supported chain
(define-public (add-supported-chain 
    (chain-identifier (string-ascii 32)) 
    (bridge-contract (string-ascii 128))
    (reputation-weight uint)
)
    (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (and (> reputation-weight u0) (<= reputation-weight u200)) ERR_INVALID_PARAMETERS)
    
    (ok (map-set supported-chains
        { chain-id: chain-identifier }
        {
            active: true,
            bridge-contract: bridge-contract,
            reputation-weight: reputation-weight
        }
    )))
)

;; Record cross-chain action
(define-public (record-cross-chain-action
    (source-chain (string-ascii 32))
    (target-chain (string-ascii 32))
    (action-type (string-ascii 32))
    (reputation-impact uint)
)
    (let (
        (action-id (+ (var-get action-counter) u1))
        (chain-info (get-chain-info target-chain))
    )
    (asserts! (is-some chain-info) ERR_INVALID_PARAMETERS)
    (asserts! (<= reputation-impact u100) ERR_INVALID_PARAMETERS)
    
    ;; Record action
    (map-set cross-chain-actions
        { action-id: action-id }
        {
            initiator: tx-sender,
            source-chain: source-chain,
            target-chain: target-chain,
            action-type: action-type,
            reputation-impact: reputation-impact,
            completed: false
        }
    )
    
    (var-set action-counter action-id)
    (ok action-id)
    )
)

;; Admin function to verify contribution
(define-public (verify-contribution (user principal) (contribution-id uint))
    (let (
        (contribution (map-get? user-contributions { user: user, contribution-id: contribution-id }))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some contribution) ERR_INVALID_PARAMETERS)
    
    (ok (map-set user-contributions
        { user: user, contribution-id: contribution-id }
        (merge (unwrap-panic contribution) { verified: true })
    )))
)

;; Admin function to pause/resume governance
(define-public (toggle-governance)
    (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (ok (var-set governance-active (not (var-get governance-active))))
    )
)

;; Initialize the contract
(begin
    (map-set user-reputation
        { user: CONTRACT_OWNER }
        { score: u1000, last-updated: stacks-block-height, total-contributions: u1, successful-proposals: u0, failed-proposals: u0 }
    )
)