# CharterManager

This is a vault manager that supports origination fees and permissioned vaults.

The manager wraps the Vat and the AuthJoin adapter. Similarly to the CropJoin design, it creates proxy accounts for each user, while making sure only these accounts can hold the specific ilk's gem.

There is support for an unpermissioned mode, in which anyone can create a vault and draw debt. The new debt is applicable to an origination fee (`Nib`).
In the alternative permissioned mode, each vault owner is chartered a debt ceiling (`uline`) and specific origination fee (`nib`).

When accuring debt (during `frob`) the manager contract validates the user's ceiling (if exists) and draws a portion of the created debt as system fee.

As in CropJoin, liquidations can only be done by users who created a proxy through the manager.

### Terms

- `gate` : whether the ilk is permissioned.
- `Nib` : per ilk relative fee (for unpermissioned ilks).
- `nib` : per user relative fee for a specific ilk (for permissioned ilks).
- `uline` : per user debt ceiling for a specific ilk (for permissioned ilks).
