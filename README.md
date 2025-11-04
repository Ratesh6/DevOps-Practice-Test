** Project Explanation **

This project is a fully automated backup system built using Bash scripting.
It is designed for DevOps practice to demonstrate automation, file management, logging, and reliability in system maintenance.

The goal of this project is to create reliable backups of critical files or project directories while maintaining integrity and organization. The script automatically compresses selected folders, generates checksum files for verification, logs all operations, and rotates old backups according to a retention policy.

The configuration file (backup.config) allows full customization — including destination paths, excluded patterns, checksum commands, and how many backups to keep. This makes the system flexible enough to handle different environments and use cases.

The backup process includes the following major stages:

Initialization:
Reads configuration parameters (backup destination, exclude patterns, checksum command, etc.) and validates inputs.

Backup Creation:
Creates a timestamped .tar.gz archive of the source directory, excluding unnecessary files (e.g., .git, node_modules, .cache).

Checksum Generation and Verification:
Generates a checksum (.md5 or .sha256) for each backup to ensure the backup file is not corrupted. Verification ensures data integrity before marking the process as successful.

Logging:
All activities, such as start time, backup success, checksum creation, and errors, are recorded in backup.log.
This ensures transparency and traceability of backup operations.

Backup Rotation:
Implements a retention policy that automatically removes old backups (daily, weekly, monthly) to manage disk space efficiently.

Restore Feature:
Provides a command to restore data from a specific backup archive into any directory, ensuring recovery can be performed quickly.

Automation Ready:
The system is designed to run manually or automatically through a cron job or systemd timer for scheduled backups.

Overall, this project simulates a real-world backup management system and demonstrates:
    File handling automation in Bash

    Logging and checksum validation

    Error handling and reporting

    Configurable backup policies

    Integration with Linux file system tools
