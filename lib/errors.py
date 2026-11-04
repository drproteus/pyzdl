class LoaderError(Exception):
    """Raised when a profile cannot be loaded, validated, or launched."""


class ConfigError(LoaderError):
    """Raised when the configuration file is invalid."""
