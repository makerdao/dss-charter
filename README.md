# CharterManager

This is a vault manager that supports permissioned vaults.
It allows administrating a per-vault debt ceiling and and origination fee.

The manager wraps the Vat and the AuthJoin adapter.
Similarly to the CropJoin design, it creates proxy accounts for each user, while making sure only these accounts can hold the specific ilk's gem.

When creating more debt (`frob`) the manager validates the user's vault ceiling (`line`) and draws a portion of the created debt (`nib`) as system fee. 

Unpermissioned users with a zero ceiling allocation will not be able to draw any debt through the manager.

As in CropJoin, liquidations are only allowed for users that created a proxy through the manager.

### Terms

- `line`: per user debt ceiling for a specific ilk
- `nib`: per user relative fee for a specific ilk

