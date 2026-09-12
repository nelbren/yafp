$global:DEV = 'ndev-'
$global:PRO = 'npro-'

$global:YAFP_REPOS = 1
$global:YAFP_TITLE = 1
$global:YAFP_ERROR = 1
$global:YAFP_PVENV = 1
$global:YAFP_DARKC = 1

# Check the configured upstream in the background. The value is the cache
# lifetime in seconds; set it to 0 to disable remote checks completely.
$global:YAFP_REMOTE_CHECK_INTERVAL = 300

# Display prompt construction timing; set it to 0 to disable the metrics.
$global:YAFP_DEVEL = 0

# $global:YAFP_THEME = 'default'
# $global:YAFP_THEME = 'minimal'
$global:YAFP_THEME = 'light'
