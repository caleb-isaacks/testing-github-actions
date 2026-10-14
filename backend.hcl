resource_group_name  = "tfstate-remote-storage" # Can also be set via `ARM_ACCESS_KEY` environment variable.
storage_account_name = "tfstate1635478"         # Can be passed via `-backend-config=`"storage_account_name=<storage account name>"` in the `init` command.
container_name       = "tfstate"                # Can be passed via `-backend-config=`"container_name=<container name>"` in the `init` command.
key                  = "tfstate1635478"         # Can be passed via `-backend-config=`"key=<blob key name>"` in the `init` command.