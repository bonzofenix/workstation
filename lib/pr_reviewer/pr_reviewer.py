import os
import re
import click
import requests
from bs4 import BeautifulSoup
from pathlib import Path
from openai import OpenAI

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

def fetch_file_contexts(pr_url: str, gh_token: str) -> dict:
    m = re.search(r"github\.tools\.sap/(.+?)/(.+?)/pull/(\d+)", pr_url)
    if not m:
        raise ValueError("Invalid PR URL")
    org, repo, pr_number = m.groups()
    api_url = f"https://github.tools.sap/api/v3/repos/{org}/{repo}/pulls/{pr_number}/files"

    headers = {
        "Authorization": f"token {gh_token}",
        "Accept": "application/vnd.github.v3.diff",
        "User-Agent": "pr-reviewer"
    }
    resp = requests.get(api_url, headers=headers)
    click.echo(f"GitHub API status: {resp.status_code}")
    resp.raise_for_status()

    result = {}
    for f in resp.json():
        patch = f.get("patch")
        if patch:
            result[f["filename"]] = patch

    return result

def suggest_review(path: str, file_content: str) -> str:
    prompt = f"Review the following full file content with diff markers and suggest improvements for the changes:\n\nFile: {path}\n\n{file_content}"
    resp = client.chat.completions.create(
        model="gpt-4",
        messages=[{"role": "user", "content": prompt}],
    )
    return resp.choices[0].message.content.strip()

@click.command()
@click.argument("url")
@click.option("--token", envvar="OPENAI_API_KEY", help="OpenAI API token")
@click.option("--gh-token", default=None, help="GitHub token for private PR access")
def main(url: str, token: str, gh_token: str):
    gh_token = gh_token or os.getenv("GITHUB_TOKEN") or os.getenv("GITHUB_TOOLS_TOKEN")
    if not gh_token:
        raise click.UsageError("GitHub token is required")
    files = fetch_file_contexts(url, gh_token)
    click.echo(f"Reviewing {len(files)} files...")
    for path, content in files.items():
        click.echo(f"Processing: {path}")
        suggestion = suggest_review(path, content)
        click.echo(f"{path}:\n{suggestion}\n")

if __name__ == "__main__":
    main()

