# Synergi-Link: Cross-chain Cooperative Governance Smart Contract

A sophisticated governance system built on the Stacks blockchain using Clarity smart contracts, featuring reputation-weighted voting and cross-chain coordination capabilities.

## Overview

Synergi-Link enables decentralized autonomous organizations (DAOs) to make governance decisions that can span multiple blockchain networks. The system uses a dynamic reputation mechanism to weight voting power, ensuring that active and valuable contributors have proportional influence in governance decisions.

## Key Features

### 🏆 Reputation System
- **Dynamic Scoring**: Build reputation through contributions, successful proposals, and cross-chain activities
- **Automatic Decay**: Prevents inactive users from maintaining indefinite influence
- **Multi-factor Calculation**: Considers contribution history, proposal success rate, and cross-chain participation
- **Anti-gaming Mechanisms**: Square root scaling prevents extreme power concentration

### 🗳️ Governance Mechanism
- **Reputation-Weighted Voting**: Vote weight based on user reputation
- **Minimum Thresholds**: Require minimum reputation to create proposals
- **Time-bound Decisions**: Configurable voting periods (24 hours to 30 days)
- **Automatic Execution**: Proposals execute based on weighted vote outcomes

### 🌉 Cross-chain Capabilities
- **Multi-chain Support**: Register and manage multiple blockchain networks
- **Bridge Integration**: Connect with existing cross-chain bridge contracts
- **Action Tracking**: Record and verify cross-chain activities for reputation
- **Chain-specific Weights**: Different reputation multipliers per blockchain

## Smart Contract Architecture

### Constants
```clarity
MIN_REPUTATION_TO_PROPOSE: 100    // Minimum reputation to create proposals
MIN_VOTING_PERIOD: 144 blocks     // ~24 hours minimum voting period
MAX_VOTING_PERIOD: 4320 blocks    // ~30 days maximum voting period
REPUTATION_DECAY_RATE: 2 per 1000 blocks
```

### Data Structures

#### User Reputation
```clarity
{
  score: uint,                    // Current reputation score
  last-updated: uint,             // Last update block height
  total-contributions: uint,      // Number of verified contributions
  successful-proposals: uint,     // Number of passed proposals
  failed-proposals: uint          // Number of failed proposals
}
```

#### Proposals
```clarity
{
  proposer: principal,            // Proposal creator
  title: string-utf8,            // Proposal title
  description: string-utf8,      // Detailed description
  proposal-type: string-ascii,   // Type of proposal
  target-chain: string-ascii,    // Target blockchain
  start-block: uint,             // Voting start block
  end-block: uint,               // Voting end block
  yes-votes: uint,               // Total yes vote weight
  no-votes: uint,                // Total no vote weight
  total-reputation-voted: uint,  // Total reputation that voted
  executed: bool,                // Whether proposal was executed
  passed: bool                   // Whether proposal passed
}
```

## Core Functions

### Reputation Management

#### `initialize-reputation()`
Sets up a user's reputation profile with an initial score of 50 points.

#### `add-contribution(contribution-type, reputation-earned)`
Records a contribution and awards reputation points (1-50 points per contribution).

**Parameters:**
- `contribution-type`: Type of contribution (e.g., "code", "documentation", "review")
- `reputation-earned`: Points to award (1-50)

#### `get-current-reputation(user)`
Returns the user's current reputation score after applying decay.

### Governance Functions

#### `create-proposal(title, description, proposal-type, target-chain, voting-period)`
Creates a new governance proposal (requires minimum 100 reputation).

**Parameters:**
- `title`: Proposal title (max 256 characters)
- `description`: Detailed description (max 1024 characters)
- `proposal-type`: Category of proposal
- `target-chain`: Target blockchain for execution
- `voting-period`: Duration in blocks (144-4320)

#### `vote-on-proposal(proposal-id, vote)`
Cast a reputation-weighted vote on an active proposal.

**Parameters:**
- `proposal-id`: ID of the proposal
- `vote`: true for yes, false for no

#### `execute-proposal(proposal-id)`
Executes a proposal after voting period ends and updates proposer reputation.

### Cross-chain Functions

#### `add-supported-chain(chain-identifier, bridge-contract, reputation-weight)`
Registers a new blockchain network (admin only).

**Parameters:**
- `chain-identifier`: Unique chain identifier
- `bridge-contract`: Bridge contract address
- `reputation-weight`: Reputation multiplier (1-200)

#### `record-cross-chain-action(source-chain, target-chain, action-type, reputation-impact)`
Records a cross-chain activity for reputation building.

## Voting Power Calculation

Voting power is calculated to prevent extreme concentration while rewarding reputation:

```
voting_power = 1 + (reputation / 10)
```

This ensures:
- Minimum voting power of 1 for all users
- Proportional but not overwhelming influence for high-reputation users

## Reputation Decay

Reputation decays over time to ensure active participation:

```
decay_amount = (blocks_passed * REPUTATION_DECAY_RATE) / 1000
current_reputation = max(0, original_reputation - decay_amount)
```

## Deployment Guide

### Prerequisites
- Clarinet CLI installed
- Stacks blockchain testnet/mainnet access
- STX tokens for deployment

### Steps

1. **Clone and Setup**
```bash
git clone <your-repo>
cd Synergi-Link
clarinet check
```

2. **Test Locally**
```bash
clarinet console
```

3. **Deploy to Testnet**
```bash
clarinet deploy --testnet
```

4. **Initialize Contract**
After deployment, the contract owner will have initial reputation of 1000 points.

## Usage Examples

### Creating a Proposal
```clarity
(contract-call? .synergi-link create-proposal 
  u"Upgrade Bridge Contract" 
  u"Proposal to upgrade the Ethereum bridge contract to support EIP-4844"
  "technical-upgrade"
  "ethereum"
  u1440) ;; 10 days voting period
```

### Voting on a Proposal
```clarity
(contract-call? .synergi-link vote-on-proposal u1 true) ;; Vote yes on proposal #1
```

### Adding Reputation through Contribution
```clarity
(contract-call? .synergi-link add-contribution "code-review" u25)
```

## Security Considerations

### Access Controls
- Only contract owner can verify contributions
- Only contract owner can add supported chains
- Only contract owner can pause governance

### Anti-gaming Measures
- Reputation decay prevents inactive influence
- Square root voting power scaling
- Minimum reputation thresholds for proposals
- Time-based voting periods

### Error Handling
The contract includes comprehensive error codes:
- `ERR_UNAUTHORIZED (u100)`: Access denied
- `ERR_PROPOSAL_NOT_FOUND (u101)`: Invalid proposal ID
- `ERR_PROPOSAL_EXPIRED (u102)`: Voting period ended
- `ERR_ALREADY_VOTED (u103)`: Double voting attempt
- `ERR_INSUFFICIENT_REPUTATION (u104)`: Below minimum reputation
- `ERR_INVALID_PARAMETERS (u105)`: Invalid input parameters
- `ERR_PROPOSAL_ALREADY_EXECUTED (u106)`: Proposal already processed

## Testing

### Unit Tests
```bash
npm install
npm test
```

### Integration Tests
Test scenarios should cover:
- Reputation building and decay
- Proposal creation and voting
- Cross-chain action recording
- Edge cases and error conditions

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

[MIT License](LICENSE)

## Support

For questions and support:
- Create an issue on GitHub
- Review the Clarity documentation
- Check the Stacks blockchain documentation

## Roadmap

### Phase 1 (Current)
- ✅ Basic reputation system
- ✅ Proposal creation and voting
- ✅ Cross-chain registry

### Phase 2 (Planned)
- [ ] Integration with major bridge protocols
- [ ] Advanced reputation algorithms
- [ ] Multi-signature proposal execution
- [ ] Governance analytics dashboard

### Phase 3 (Future)
- [ ] AI-assisted proposal analysis
- [ ] Automated cross-chain execution
- [ ] Reputation NFT system
- [ ] Mobile governance app
