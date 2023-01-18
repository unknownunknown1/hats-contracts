module.exports = {
    "goerli": {
        "governance": "0xFc9F1d127f8047B0F41e9eAC2Adc2e5279C568B7",
        "timelockDelay": 300,
        "executors": [
            "0x2bc1fed4c65c9b1dc2baaff2f3198acc42c41778"
        ],
        "rewardControllersConf": [],
        "hatVaultsRegistryConf": {
            "swapToken": "0x07865c6E87B9F70255377e024ace6630C1Eaa37F", // USDC
            "bountyGovernanceHAT": "1000",
            "bountyHackerHATVested": "500"
        },
        "hatVaultsNFTConf": {
            "merkleTreeIPFSRef": "",
            "root": null,
            "deadline": null
        }
    },
    "optimism_goerli": {
        "governance": "0x0B7602011EC2B862Bc157fF08d27b1018aEb18d5",
        "timelockDelay": 300,
        "executors": [
            "0x0B7602011EC2B862Bc157fF08d27b1018aEb18d5"
        ],
        "rewardControllersConf": [{
            "startBlock": null,
            "epochLength": "195200",
            "epochRewardPerBlock": [
                "441300000000000000000",
                "441300000000000000000",
                "882500000000000000000",
                "778800000000000000000",
                "687300000000000000000",
                "606500000000000000000",
                "535300000000000000000",
                "472400000000000000000",
                "416900000000000000000",
                "367900000000000000000",
                "324700000000000000000",
                "286500000000000000000",
                "252800000000000000000",
                "223100000000000000000",
                "196900000000000000000",
                "173800000000000000000",
                "153400000000000000000",
                "135300000000000000000",
                "119400000000000000000",
                "105400000000000000000",
                "93000000000000000000",
                "82100000000000000000",
                "72400000000000000000",
                "63900000000000000000"
            ]
        }],
        "hatVaultsRegistryConf": {
            "bountyGovernanceHAT": "1000",
            "bountyHackerHATVested": "500"
        },
        "hatVaultsNFTConf": {
            "merkleTreeIPFSRef": "",
            "root": null,
            "deadline": null
        }
    },
    "hardhat": {
        "timelockDelay": 300,
        "rewardControllersConf": [{
            "startBlock": null,
            "epochLength": "195200",
            "epochRewardPerBlock": [
                "441300000000000000000",
                "441300000000000000000",
                "882500000000000000000",
                "778800000000000000000",
                "687300000000000000000",
                "606500000000000000000",
                "535300000000000000000",
                "472400000000000000000",
                "416900000000000000000",
                "367900000000000000000",
                "324700000000000000000",
                "286500000000000000000",
                "252800000000000000000",
                "223100000000000000000",
                "196900000000000000000",
                "173800000000000000000",
                "153400000000000000000",
                "135300000000000000000",
                "119400000000000000000",
                "105400000000000000000",
                "93000000000000000000",
                "82100000000000000000",
                "72400000000000000000",
                "63900000000000000000"
            ],
            "rewardToken": "HATToken"
        }],
        "hatVaultsRegistryConf": {
            "bountyGovernanceHAT": "1000",
            "bountyHackerHATVested": "500",
            "swapToken": "HATToken"
        },
        "hatVaultsNFTConf": {
            "merkleTreeIPFSRef": "",
            "root": null,
            "deadline": null
        }
    },
    "polygon": {
        "governance": "0xFc9F1d127f8047B0F41e9eAC2Adc2e5279C568B7",
        "timelockDelay": 300,
        "executors": [ ],
        "rewardControllersConf": [],
        "hatToken": "0x2791bca1f2de4661ed88a30c99a7a9449aa84174", 
        "hatVaultsRegistryConf": {
          "bountyGovernanceHAT": "0",
          "bountyHackerHATVested": "0"
      },
      "hatVaultsNFTConf": {
          "merkleTreeIPFSRef": "",
          "root": null,
          "deadline": null
      }
    },
    "sepolia": {
      "governance": "0xFc9F1d127f8047B0F41e9eAC2Adc2e5279C568B7",
      "timelockDelay": 300,
      "executors": [], // proposal executors - if this empty, governance will be an executor
      "rewardControllersConf": [], // no reward controllers
      "hatToken": "",  // deploy a fresh HATToken contract
      "hatVaultsRegistryConf": {
        "bountyGovernanceHAT": "0",
        "bountyHackerHATVested": "0"
      }
    }
};