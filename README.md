# Pricarr - Price Tracking System

A Phoenix LiveView application for tracking product prices across multiple retailers (starting with Amazon) and receiving alerts when prices drop.

## Features

- **Product Management**: Track multiple products with customizable names and descriptions
- **Multi-URL Support**: Track the same product across different retailers or multiple listings
- **Flexible Price Checking**: Configure check intervals per URL (minutes/hours/days)
- **Smart Alerts**: Get notified when prices drop below a target or by a percentage
- **Multiple Notification Channels**: Use Apprise to send alerts via email, Discord, Pushover, Ntfy, and more
- **Price History**: View historical price data for each product URL
- **Pluggable Scraper Architecture**: Easy to add new retailers beyond Amazon
- **Background Jobs**: Efficient price checking with Oban
- **SQLite Database**: Lightweight, no separate database server needed

## Tech Stack

- **Phoenix 1.7** with **LiveView** for real-time UI
- **Oban** for background job processing
- **SQLite** via ecto_sqlite3 for data storage
- **Req + Floki** for web scraping
- **Apprise** for multi-channel notifications
- **Docker** for development environment

## Getting Started

### Prerequisites

- Docker and Docker Compose
- OR Elixir 1.16+ and Erlang 26+ (for local development)

### Quick Start with Docker

1. **Setup and start the application:**

```bash
make setup
make dev
```

This will:
- Build the Docker container
- Create the SQLite database
- Run migrations
- Start the Phoenix server

2. **Access the application:**

Open http://localhost:4000 in your browser

3. **Load sample data (optional):**

```bash
docker-compose exec app mix run priv/repo/seeds.exs
```

### Local Development (without Docker)

1. **Install dependencies:**

```bash
mix deps.get
cd assets && npm install && cd ..
```

2. **Setup database:**

```bash
mix ecto.create
mix ecto.migrate
```

3. **Install Apprise:**

```bash
pip install apprise
```

4. **Start the server:**

```bash
mix phx.server
```

Visit http://localhost:4000

## Usage

### Adding a Product

1. Navigate to **Products** → **Add Product**
2. Enter product name and optional description
3. Click **Save Product**

### Adding URLs to Track

1. Go to a product's detail page
2. Click **Add URL**
3. Enter:
   - Amazon product URL
   - Retailer name (e.g., "Amazon")
   - Check interval in minutes
4. Click **Save URL**

The price checker will automatically schedule a job to check this URL.

### Setting Up Alerts

1. Navigate to **Alerts** → **Create Alert**
2. Select the product to track
3. Choose trigger type:
   - **Below target price**: Alert when price drops below a specific amount
   - **Percentage drop**: Alert when price drops by a certain percentage
   - **Either condition**: Alert on either trigger
4. Add notification URLs (Apprise format):
   - Email: `mailto://user:password@gmail.com`
   - Discord: `discord://webhook_id/webhook_token`
   - Pushover: `pover://user@token`
   - Ntfy: `ntfy://ntfy.sh/topic`
   - [See Apprise docs for more](https://github.com/caronc/apprise)
5. Set cooldown period to prevent spam
6. Save the alert

### Monitoring

- **Dashboard**: View all products, best prices, and recent alerts
- **Product Pages**: See detailed price history and tracking status
- **Alert Logs**: View notification history and success/failure status

## Configuration

### Check Intervals

Each product URL can have its own check interval:
- Minimum: 1 minute (not recommended for Amazon)
- Recommended: 60-180 minutes to avoid rate limiting
- Maximum: Any duration

### Alert Cooldowns

Prevent alert spam by setting a cooldown period (in minutes) between notifications for the same product.

### Database Location

The SQLite database is stored in:
- Docker: `./data/pricarr_dev.db`
- Local: `./pricarr_dev.db` (in the project root)

## Architecture

### Contexts

- **Products**: Manages products, URLs, and price history
- **Alerts**: Handles alert rules, notifications, and logs
- **Scrapers**: Pluggable scraper system for different retailers
- **Workers**: Oban background jobs for price checking and alerts

### Key Modules

- `Pricarr.Scrapers.Amazon.SimpleHTTP`: Amazon scraper using HTTP requests
- `Pricarr.Workers.PriceChecker`: Background worker for price checking
- `Pricarr.Workers.AlertSender`: Background worker for sending notifications
- `Pricarr.Alerts.Notifier`: Apprise integration for notifications

### Adding New Scrapers

1. Create a new module implementing `Pricarr.Scrapers.BaseScraper` behavior
2. Implement `can_handle?/1` and `scrape_price/1` callbacks
3. Add the scraper to `Pricarr.Scrapers.ScraperRegistry`

Example:

```elixir
defmodule Pricarr.Scrapers.Walmart.SimpleHTTP do
  @behaviour Pricarr.Scrapers.BaseScraper

  def can_handle?(url) do
    String.contains?(url, "walmart.com")
  end

  def scrape_price(url) do
    # Scraping logic here
    {:ok, %{price: price, available: true, metadata: %{}}}
  end
end
```

## Amazon Scraping Limitations

The SimpleHTTP scraper may encounter:
- **CAPTCHAs**: Amazon may challenge automated requests
- **Rate Limiting**: Too many requests can result in blocks
- **HTML Changes**: Amazon frequently updates their HTML structure

**Recommendations:**
- Keep check intervals ≥ 60 minutes
- Consider using Amazon Product Advertising API for production
- Or use third-party services like Keepa API

## Makefile Commands

- `make dev`: Start development server
- `make setup`: Initial setup (build, create DB, migrate)
- `make down`: Stop all containers
- `make logs`: View application logs
- `make shell`: Open IEx shell in running container
- `make test`: Run tests
- `make clean`: Clean all build artifacts and data
- `make rebuild`: Rebuild everything from scratch

## Troubleshooting

### Price checks not running

1. Check Oban dashboard: http://localhost:4000/dev/dashboard
2. Verify jobs are enqueued:
   ```bash
   make shell
   iex> Pricarr.Repo.all(Oban.Job) |> length()
   ```

### Notifications not sending

1. Verify Apprise is installed:
   ```bash
   docker-compose exec app which apprise
   ```
2. Test Apprise URL manually:
   ```bash
   docker-compose exec app apprise -t "Test" -b "Test message" your://url
   ```
3. Check alert logs in the UI

### Scraping failures

1. Check logs: `make logs`
2. Test URL manually: Try accessing the URL in a browser
3. Amazon may be blocking - consider:
   - Increasing check intervals
   - Using proxies
   - Switching to official API

## Contributing

The scraper architecture is designed to be extensible. To add support for new retailers:

1. Create a scraper module in `lib/pricarr/scrapers/[retailer]/`
2. Implement the `BaseScraper` behavior
3. Register in `ScraperRegistry`
4. Update the UI to support the new retailer

## License

[Your chosen license]

## Support

For issues and questions:
- Check the troubleshooting section above
- Review logs with `make logs`
- Open an issue on GitHub

---

**Note**: This application is for personal use. Respect retailers' Terms of Service and rate limits. Consider using official APIs for production use.
