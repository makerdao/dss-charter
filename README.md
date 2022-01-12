# CharterManager
![Build Status](https://github.com/makerdao/dss-charter/actions/workflows/.github/workflows/tests.yaml/badge.svg?branch=master)

This is a vault manager that supports origination fees and permissioned vaults.

The manager wraps the Vat and the ManagedGemJoin adapter. Similarly to the CropJoin design, it creates proxy accounts for each user, while making sure only these accounts can hold the specific ilk's gem.

There is support for an unpermissioned mode, in which anyone can create a vault and draw debt. The new debt is applicable to an origination fee (`Nib`).
In the alternative permissioned mode, each vault owner is chartered a debt ceiling (`uline`) and specific origination fee (`nib`).

When accruing debt (during `frob`) the manager contract validates the user's ceiling (if exists) and draws a portion of the created debt as system fee.
A minimal collateralization ratio (`Peace` / `peace`) is enforced upon drawing debt or withdrawing collateral.

As in CropJoin, liquidations can only be done by users who created a UrnProxy through the manager.

### Terms

- `gate` : whether the ilk is permissioned.
- `Nib` : per ilk relative fee (for unpermissioned ilks).
- `nib` : per user relative fee for a specific ilk (for permissioned ilks).
- `Peace`: minimal collateralization ratio (for vaults in unpermissioned ilks).
- `peace`: per user minimal collateralization ratio (for vaults in permissioned ilks).
- `uline` : per user debt ceiling for a specific ilk (for permissioned ilks).
- `rollable` : whether a vault can move debt to another vault without paying origination fees (for vaults in permissioned ilks). 

### Proxy Actions

This repository also includes proxy action functions, located in the DssProxyActionsCharter and DssProxyActionsEndCharter contracts. They are to be used via ds-proxy, similarly to [dss-proxy-actions](https://github.com/makerdao/dss-proxy-actions).
As opposed to the original actions, these functions interact with the CharterManager and are not based on dss-cdp-manager as a CDP registry.
