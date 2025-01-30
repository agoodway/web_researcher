defmodule WebResearcher.StructuredDataExtractor do
  @moduledoc """
  Extracts and processes structured data (tables, lists, etc.) from text content.
  Handles merging of structured data from multiple sources.
  """

  use Instructor

  @doc """
  Extracts structured data from text content.
  Currently a placeholder that returns an empty list - the actual implementation
  will be handled by the LLM in the summarizer.
  """
  def extract_structured_data(_content) do
    []
  end

  @doc """
  Merges structured data from multiple sources, combining similar data types
  and removing duplicates.
  """
  def merge_structured_data(structured_data_list) when is_list(structured_data_list) do
    structured_data_list
    |> Enum.group_by(& &1.type)
    |> Enum.map(fn {type, items} ->
      case type do
        "table" -> merge_tables(items)
        "list" -> merge_lists(items)
        "key_value" -> merge_key_values(items)
        _ -> items
      end
    end)
    |> List.flatten()
    |> Enum.uniq_by(fn item -> {item.type, item.label} end)
  end

  def merge_structured_data(_), do: []

  # Merges tables with the same structure
  defp merge_tables(tables) do
    tables
    |> Enum.group_by(& &1.label)
    |> Enum.map(fn {label, items} ->
      %{
        type: "table",
        label: label,
        data: merge_table_data(items)
      }
    end)
  end

  # Merges the actual table data, combining rows and removing duplicates
  defp merge_table_data(tables) do
    tables
    |> Enum.map(& &1.data)
    |> Enum.reduce(%{}, fn table, acc ->
      Map.merge(acc, table, fn _k, v1, v2 ->
        (List.wrap(v1) ++ List.wrap(v2))
        |> Enum.uniq()
      end)
    end)
  end

  # Merges lists with the same label
  defp merge_lists(lists) do
    lists
    |> Enum.group_by(& &1.label)
    |> Enum.map(fn {label, items} ->
      %{
        type: "list",
        label: label,
        data: merge_list_data(items)
      }
    end)
  end

  # Merges list data, removing duplicates
  defp merge_list_data(lists) do
    lists
    |> Enum.flat_map(& &1.data)
    |> Enum.uniq()
  end

  # Merges key-value pairs, combining values for duplicate keys
  defp merge_key_values(key_values) do
    key_values
    |> Enum.group_by(& &1.label)
    |> Enum.map(fn {label, items} ->
      %{
        type: "key_value",
        label: label,
        data: merge_key_value_data(items)
      }
    end)
  end

  # Merges key-value data, combining values for duplicate keys
  defp merge_key_value_data(key_values) do
    key_values
    |> Enum.map(& &1.data)
    |> Enum.reduce(%{}, fn map, acc ->
      Map.merge(acc, map, fn _k, v1, v2 ->
        case {v1, v2} do
          {v1, v2} when is_list(v1) and is_list(v2) -> Enum.uniq(v1 ++ v2)
          {v1, v2} when is_list(v1) -> Enum.uniq([v2 | v1])
          {v1, v2} when is_list(v2) -> Enum.uniq([v1 | v2])
          {v1, v2} when v1 == v2 -> v1
          {v1, v2} -> [v1, v2] |> Enum.uniq()
        end
      end)
    end)
  end
end
