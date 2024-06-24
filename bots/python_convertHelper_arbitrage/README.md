# .ENV file

just change .envExample to .env and add what is needed.

# The following packages are needed:

1. **web3.py**: This is the official Ethereum Python library, allowing interaction with the Ethereum blockchain.

    ```bash
   pip install web3
    ```
2. **python-dotenv**: A module to read key-value pairs from a.env file.

   ```bash
   pip install python-dotenv
    ```
3. **requests**: A popular HTTP library for making requests to web services.

   ```bash
   pip install requests
    ```

# Crontab for running it every two hours:

Using `crontab` in Windows Subsystem for Linux (WSL) is straightforward. Here’s how you can set up and use `crontab` in WSL:

### Step 1: Install `cron`

If `cron` is not already installed on your WSL, you can install it using the following command:

```sh
sudo apt-get update
sudo apt-get install cron
```

### Step 2: Start the `cron` Service

After installing `cron`, you need to start the service. You can start `cron` with the following command:

```sh
sudo service cron start
```

### Step 3: Verify the `cron` Service is Running

To ensure that the `cron` service is running, use the following command:

```sh
sudo service cron status
```

### Step 4: Edit the `crontab` File

To edit the `crontab` file for the current user, use the following command:

```sh
crontab -e
```

This command opens the `crontab` file in your default text editor. You can add your cron jobs in this file. For example, to run a script every day at midnight, you would add:

```sh
0 0 * * * /path/to/your/script.sh
```

### Step 5: Save and Exit the `crontab` Editor

After adding your cron job, save the file and exit the text editor. The `cron` service will automatically pick up the changes.

### Step 6: Verify the `crontab` Entries

To list the current `crontab` entries for the current user, use:

```sh
crontab -l
```

### Example Cron Job for running Python script every two hours

Here’s an example of setting up a cron job that runs a script located at `/home/username/scripts/my_script.sh` every two hours:

1. Open the `crontab` editor:

    ```sh
    crontab -e
    ```

2. Add the following line to the `crontab` file:

    ```sh
    0 */2 * * * /usr/bin/python3 /home/ubuntu/Utilities/arbitrage/script.py  ### every two hours
    ```

3. Save and exit the editor.