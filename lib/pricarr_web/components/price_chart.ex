defmodule PricarrWeb.PriceChart do
  @moduledoc """
  Component for rendering price history charts using Contex.
  """
  use Phoenix.Component

  alias Contex.{Dataset, PointPlot, Plot}

  @doc """
  Renders a price history line chart.

  ## Attributes

    * `:data` - List of maps with :retailer, :checked_at, and :price keys
    * `:width` - Chart width in pixels (default: 600)
    * `:height` - Chart height in pixels (default: 300)
  """
  attr :data, :list, required: true
  attr :width, :integer, default: 600
  attr :height, :integer, default: 300

  def price_chart(assigns) do
    assigns = assign(assigns, :svg, build_chart(assigns.data, assigns.width, assigns.height))

    ~H"""
    <div class="price-chart text-base-content">
      <%= if @svg do %>
        <%= Phoenix.HTML.raw(@svg) %>
      <% else %>
        <div class="text-center py-8 opacity-70">
          <p>No price history data available yet.</p>
        </div>
      <% end %>
    </div>
    """
  end

  defp build_chart([], _width, _height), do: nil

  defp build_chart(data, width, height) do
    if Enum.empty?(data) do
      nil
    else
      # Convert data to simple rows: [time, price, retailer]
      rows =
        data
        |> Enum.filter(fn d -> d.price != nil end)
        |> Enum.map(fn d ->
          [
            DateTime.to_unix(d.checked_at),
            d.price |> Decimal.round(2) |> Decimal.to_float(),
            d.retailer
          ]
        end)

      if Enum.empty?(rows) do
        nil
      else
        dataset = Dataset.new(rows, ["Time", "Price", "Retailer"])

        # Calculate Y-axis range with padding
        all_prices = Enum.map(rows, fn [_, price, _] -> price end)

        {min_price, max_price} =
          case all_prices do
            [] -> {0, 100}
            prices ->
              min_p = Enum.min(prices)
              max_p = Enum.max(prices)

              # Add 10% padding, or at least $5 if prices are identical
              range = max_p - min_p
              padding = if range < 1, do: 5.0, else: range * 0.1

              {max(0, min_p - padding), max_p + padding}
          end

        # Build the plot with colors that work in both light and dark themes
        plot_options = [
          mapping: %{x_col: "Time", y_cols: ["Price"], fill_col: "Retailer"},
          colour_palette: ["818cf8", "34d399", "fbbf24", "f87171", "60a5fa"],
          custom_x_formatter: &format_date/1,
          custom_y_formatter: &format_price/1,
          custom_y_scale: Contex.ContinuousLinearScale.new()
            |> Contex.ContinuousLinearScale.domain(min_price, max_price)
        ]

        plot =
          Plot.new(dataset, PointPlot, width, height, plot_options)
          |> Plot.titles("Price History", "")
          |> Plot.axis_labels("Date", "Price ($)")
          |> Plot.plot_options(%{legend_setting: :legend_right})
          |> Map.put(:default_style, false)

        svg =
          case Plot.to_svg(plot) do
            {:safe, iodata} -> IO.iodata_to_binary(iodata)
            iodata when is_list(iodata) -> IO.iodata_to_binary(iodata)
            binary when is_binary(binary) -> binary
          end

        # Add lines between points, tooltips, and theme-aware styling
        svg
        |> add_lines_between_points()
        |> add_tooltips(rows)
        |> add_theme_styles()
      end
    end
  end

  defp format_date(value) when is_number(value) do
    value
    |> trunc()
    |> DateTime.from_unix!()
    |> then(fn dt -> "#{dt.month}/#{dt.day}" end)
  end

  defp format_date(value), do: to_string(value)

  defp format_price(value) when is_number(value) do
    :erlang.float_to_binary(value * 1.0, decimals: 2)
  end

  defp format_price(value), do: to_string(value)

  defp add_lines_between_points(svg) do
    # Extract circle positions and colors from SVG
    # Attributes can be in any order, so we need to extract them separately
    circle_pattern = ~r/<circle[^>]+>/

    circles =
      Regex.scan(circle_pattern, svg)
      |> Enum.map(fn [circle] ->
        cx = case Regex.run(~r/cx="([^"]+)"/, circle) do
          [_, val] -> String.to_float(val)
          _ -> nil
        end
        cy = case Regex.run(~r/cy="([^"]+)"/, circle) do
          [_, val] -> String.to_float(val)
          _ -> nil
        end
        fill = case Regex.run(~r/style="fill:([^"]+);"/, circle) do
          [_, val] -> val
          _ -> "#000"
        end
        {cx, cy, fill}
      end)
      |> Enum.filter(fn {cx, cy, _} -> cx != nil and cy != nil end)

    if length(circles) < 2 do
      svg
    else
      # Group circles by color (each color = one retailer)
      grouped = Enum.group_by(circles, fn {_, _, fill} -> fill end)

      # Build path elements for lines
      lines =
        Enum.flat_map(grouped, fn {color, points} ->
          # Sort by x position (time)
          sorted = Enum.sort_by(points, fn {x, _, _} -> x end)

          # Create line segments between consecutive points
          # Use the actual fill color as the stroke color
          sorted
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.map(fn [{x1, y1, _}, {x2, y2, _}] ->
            ~s(<line x1="#{x1}" y1="#{y1}" x2="#{x2}" y2="#{y2}" stroke="#{color}" stroke-width="2" />)
          end)
        end)
        |> Enum.join("\n")

      # Insert lines before circles so circles appear on top
      # Find the first circle and insert lines before it
      case Regex.run(~r/<circle/, svg, return: :index) do
        [{start, _}] ->
          {before, after_} = String.split_at(svg, start)
          before <> lines <> after_

        nil ->
          svg
      end
    end
  end

  defp add_tooltips(svg, rows) do
    # Build tooltip texts for each data point
    tooltips =
      Enum.map(rows, fn [timestamp, price, retailer] ->
        dt = DateTime.from_unix!(trunc(timestamp))
        formatted_time = Calendar.strftime(dt, "%Y-%m-%d %H:%M")
        formatted_price = :erlang.float_to_binary(price * 1.0, decimals: 2)

        "#{retailer}\n$#{formatted_price}\n#{formatted_time}"
      end)

    # Find all circle elements
    circles = Regex.scan(~r/<circle[^>]*>/, svg) |> Enum.map(fn [c] -> c end)

    # Replace each <circle> with version that has title
    {result, _} =
      Enum.reduce(circles, {svg, tooltips}, fn circle, {current_svg, remaining_tooltips} ->
        case remaining_tooltips do
          [tooltip | rest] ->
            escaped_tooltip =
              tooltip
              |> String.replace("&", "&amp;")
              |> String.replace("<", "&lt;")
              |> String.replace(">", "&gt;")

            new_circle =
              if String.ends_with?(circle, "/>") do
                String.replace(circle, "/>", "><title>#{escaped_tooltip}</title></circle>")
              else
                String.replace(circle, ">", "><title>#{escaped_tooltip}</title>")
              end

            new_svg = String.replace(current_svg, circle, new_circle, global: false)
            {new_svg, rest}

          [] ->
            {current_svg, []}
        end
      end)

    result
  end

  defp add_theme_styles(svg) do
    # Add CSS styles that use currentColor for text and axis elements
    # The parent container should have text-base-content class
    style = """
    <style>
      text {
        fill: currentColor !important;
      }
      .exc-domain, .exc-tick line {
        stroke: currentColor;
        opacity: 0.3;
      }
    </style>
    """

    # Insert style after opening <svg> tag
    case Regex.run(~r/<svg[^>]*>/, svg, return: :index) do
      [{start, len}] ->
        {before, rest} = String.split_at(svg, start + len)
        before <> style <> rest

      nil ->
        svg
    end
  end
end
