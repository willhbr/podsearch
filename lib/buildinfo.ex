defmodule BuildInfo do
  defmacro __using__(_) do
    info = get_build_info()

    quote do
      def build_info do
        unquote(Macro.escape(info))
      end
    end
  end

  defstruct [
    :commit_author,
    :commit_hash,
    :commit_time,
    :build_time,
    :version,
    :is_dirty
  ]

  defp get_build_info do
    {hash, commit_date, author} = latest_commit()
    time = current_time()
    latest_tag = get_tag()
    is_dirty = tag_hash(latest_tag) == hash

    %BuildInfo{
      commit_author: author,
      commit_hash: hash,
      commit_time: commit_date,
      build_time: time,
      version: latest_tag,
      is_dirty: is_dirty
    }
  end

  defp latest_commit do
    {info, 0} =
      System.cmd(
        "git",
        ["log", "-1", "--format=%h|%cd|%an", "HEAD"]
      )

    [hash, commit_date, author] = info |> String.trim() |> String.split("|")
    {hash, commit_date, author}
  end

  defp current_time do
    {{y, m, d}, {h, min, s}} = :calendar.universal_time()
    t_s = &Integer.to_string/1

    now =
      t_s.(y) <>
        "-" <>
        t_s.(m) <>
        "-" <> t_s.(d) <> " " <> t_s.(h) <> ":" <> t_s.(min) <> ":" <> t_s.(s)

    now <> " UTC"
  end

  defp get_tag do
    {tags, 0} = System.cmd("git", ["tag"])

    (["0.0.0"] ++ String.split(tags, "\n"))
    |> Enum.filter(fn
      "" -> false
      _ -> true
    end)
    |> List.last()
  end

  defp tag_hash(tag) do
    case System.cmd("git", ["log", "-1", "--format=%h", tag], stderr_to_stdout: true) do
      {hash, 0} ->
        String.trim(hash)

      _ ->
        ""
    end
  end
end

defimpl String.Chars, for: BuildInfo do
  def to_string(%{
        commit_author: commit_author,
        commit_hash: commit_hash,
        commit_time: commit_time,
        build_time: build_time,
        version: version,
        is_dirty: is_dirty
      }) do
    dirty_string =
      if is_dirty do
        "+ ("
      else
        " ("
      end

    "v" <>
      version <>
      dirty_string <>
      commit_hash <>
      ") by " <>
      commit_author <> " at " <> commit_time <> " built at " <> build_time
  end
end
