### Setup

1. Install dependecies

```sh
pip install -r requirements
```

2. Update the `.env` file with `PRIVATE_KEY` which has funds so it can trigger arbitrage when needed

```sh
cp .env.example .env
```

3. Setup cron

```sh
crontab -e
```

it should open cron config, paste at the end

```sh
0 */2 * * * python3 /path/to/your/script/bot.py
```
