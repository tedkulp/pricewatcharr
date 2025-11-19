# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Pricarr.Repo.insert!(%Pricarr.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Pricarr.Products
alias Pricarr.Alerts
alias Pricarr.Workers.PriceChecker

# Clear existing data
IO.puts("Clearing existing data...")
Pricarr.Repo.delete_all(Pricarr.Alerts.AlertLog)
Pricarr.Repo.delete_all(Pricarr.Alerts.AlertRule)
Pricarr.Repo.delete_all(Pricarr.Products.PriceHistory)
Pricarr.Repo.delete_all(Pricarr.Products.ProductUrl)
Pricarr.Repo.delete_all(Pricarr.Products.Product)

IO.puts("Creating sample products...")

# Example Product 1
{:ok, laptop} =
  Products.create_product(%{
    name: "Dell XPS 13 Laptop",
    description: "13-inch ultrabook with Intel Core i7",
    active: true
  })

{:ok, laptop_url1} =
  Products.create_product_url(%{
    product_id: laptop.id,
    url: "https://www.amazon.com/dp/B0BSHF7WHW",
    retailer: "Amazon",
    check_interval_minutes: 60,
    active: true
  })

# Schedule initial price check
PriceChecker.schedule_check(laptop_url1.id)

# Example Product 2
{:ok, headphones} =
  Products.create_product(%{
    name: "Sony WH-1000XM5 Headphones",
    description: "Wireless noise-canceling headphones",
    active: true
  })

{:ok, headphones_url1} =
  Products.create_product_url(%{
    product_id: headphones.id,
    url: "https://www.amazon.com/dp/B09XS7JWHH",
    retailer: "Amazon",
    check_interval_minutes: 120,
    active: true
  })

PriceChecker.schedule_check(headphones_url1.id)

# Example Product 3
{:ok, monitor} =
  Products.create_product(%{
    name: "LG 27-inch 4K Monitor",
    description: "27-inch UHD IPS display",
    active: true
  })

{:ok, monitor_url1} =
  Products.create_product_url(%{
    product_id: monitor.id,
    url: "https://www.amazon.com/dp/B07PGL2WVS",
    retailer: "Amazon",
    check_interval_minutes: 180,
    active: true
  })

PriceChecker.schedule_check(monitor_url1.id)

IO.puts("Creating sample alert rules...")

# Note: Apprise URLs are examples. Update with your actual notification URLs.
# Examples:
# - Email: "mailto://user:password@gmail.com"
# - Discord: "discord://webhook_id/webhook_token"
# - Pushover: "pover://user@token"
# - Ntfy: "ntfy://ntfy.sh/your_topic"

{:ok, _alert1} =
  Alerts.create_alert_rule(%{
    name: "Laptop Price Drop Alert",
    product_id: laptop.id,
    trigger_type: :below_price,
    target_price: Decimal.new("999.99"),
    apprise_urls: ["ntfy://pricarr_laptop"],
    enabled: true,
    cooldown_minutes: 60
  })

{:ok, _alert2} =
  Alerts.create_alert_rule(%{
    name: "Headphones 10% Drop",
    product_id: headphones.id,
    trigger_type: :percentage_drop,
    percentage_threshold: Decimal.new("10"),
    apprise_urls: ["ntfy://pricarr_headphones"],
    enabled: true,
    cooldown_minutes: 120
  })

{:ok, _alert3} =
  Alerts.create_alert_rule(%{
    name: "Monitor Deal Alert",
    product_id: monitor.id,
    trigger_type: :both,
    target_price: Decimal.new("299.99"),
    percentage_threshold: Decimal.new("15"),
    apprise_urls: ["ntfy://pricarr_monitor"],
    enabled: true,
    cooldown_minutes: 180
  })

IO.puts("""

✅ Seed data created successfully!

Products created: 3
- Dell XPS 13 Laptop
- Sony WH-1000XM5 Headphones
- LG 27-inch 4K Monitor

Alert rules created: 3

⚠️  Note: The Apprise notification URLs are set to examples (ntfy://...).
   To receive actual notifications, edit the alert rules in the UI with your
   real notification URLs.

   Examples:
   - Email: mailto://user:password@gmail.com
   - Discord: discord://webhook_id/webhook_token
   - Pushover: pover://user@token
   - Ntfy: ntfy://ntfy.sh/your_topic

🚀 Initial price checks have been scheduled for all products.
   You can view the dashboard at http://localhost:4000
""")
