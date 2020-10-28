# ffpass
Api Calls for Ford vehicles equipped with the fordpass app.

# Documentation
https://bunkford.github.io/ffpass/docs/ffpass.html

# Installation

`nimble install https://github.com/bunkford/ffpass/`

# Example

```nim
import ffpass
  
var ford = Vehicle(username:"user@email.com", password:"myPassword", vin:"1FT#############")

if ford.lock():
  echo "Vehicle Locked"
else:
  echo "Failed to lock Vehicle"
```
