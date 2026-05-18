#![warn(clippy::pedantic)]
#![forbid(unsafe_code)]

use std::fmt::Write as _;
use std::path::{Path, PathBuf};

struct Cli {
    title: String,
    venue: Option<String>,
    steps: usize,
}

fn main() -> std::process::ExitCode {
    let args: Vec<String> = std::env::args().collect();
    match run(&args) {
        Ok(()) => std::process::ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("error: {e}");
            std::process::ExitCode::FAILURE
        }
    }
}

fn run(args: &[String]) -> Result<(), Box<dyn std::error::Error>> {
    let cli = parse_args(args)?;
    let cwd = std::env::current_dir()?;
    let talk_path = create_talk_dir(&cwd, &cli.title, cli.venue.as_deref(), cli.steps)?;
    println!("created {}", talk_path.display());

    // append to central readme's markdown list of talks
    let central_readme = cwd.join("README.md");
    if central_readme.exists() {
        let mut content = std::fs::read_to_string(&central_readme)?;
        let relative_path = talk_path.strip_prefix(&cwd)?;
        writeln!(
            content,
            "- [{}](./{}/README.md)",
            cli.title,
            relative_path.display()
        )?;
        std::fs::write(&central_readme, content)?;
    }

    Ok(())
}

fn parse_args(args: &[String]) -> Result<Cli, Box<dyn std::error::Error>> {
    let mut title = None;
    let mut venue: Option<String> = None;
    let mut steps = 0;
    let mut i = 1; // skip args[0] (the binary name)
    while i < args.len() {
        match args[i].as_str() {
            "--steps" => {
                let n = args.get(i + 1).ok_or("--steps requires a value")?;
                steps = n.parse()?;
                i += 2;
            }
            "--venue" => {
                let v = args.get(i + 1).ok_or("--venue requires a value")?;
                venue = if v.is_empty() { None } else { Some(v.clone()) };
                i += 2;
            }
            other if title.is_none() => {
                title = Some(other.to_string());
                i += 1;
            }
            other => {
                return Err(format!("unexpected argument: {other}").into());
            }
        }
    }
    let title = title.ok_or("title argument is required")?;
    Ok(Cli {
        title,
        venue,
        steps,
    })
}

fn title_to_dirname(title: &str) -> Result<String, Box<dyn std::error::Error>> {
    let mut dirname = String::with_capacity(title.len());
    let mut last_was_dash = false;
    for c in title.chars() {
        if c.is_alphanumeric() || c == '-' {
            dirname.push(c);
            last_was_dash = c == '-';
        } else if c.is_whitespace() && !last_was_dash {
            dirname.push('-');
            last_was_dash = true;
        }
    }
    dirname = dirname.trim_matches('-').to_string();
    if dirname.is_empty() {
        return Err("Title must contain at least one alphanumeric character".into());
    }
    Ok(dirname)
}

fn readme_skeleton(title: &str, venue: Option<&str>) -> String {
    let venue = venue.unwrap_or("TODO:Venue");
    format!(
        "# {title}\n\n## Abstract\n\nTODO\n\n## Presented at\n\n- TODO:Date @ [{venue}](TODO:URL)\n"
    )
}

const SCRIPT_PREAMBLE: &str = include_str!("../templates/script-preamble.sh");
const PRE_SETUP_BODY: &str = include_str!("../templates/pre-setup-body.sh");

fn setup_script_skeleton() -> String {
    format!("{SCRIPT_PREAMBLE}# TODO: implement\n")
}

fn pre_setup_script_skeleton(venue: Option<&str>) -> Result<String, Box<dyn std::error::Error>> {
    let cluster_name = match venue {
        Some(v) => title_to_dirname(v)?.to_lowercase(),
        None => "TODO-CLUSTER".to_string(),
    };
    let body = PRE_SETUP_BODY.replace("TODO-CLUSTER", &cluster_name);
    Ok(format!("{SCRIPT_PREAMBLE}{body}"))
}

fn create_talk_dir(
    parent: &Path,
    title: &str,
    venue: Option<&str>,
    steps: usize,
) -> Result<PathBuf, Box<dyn std::error::Error>> {
    let dirname = title_to_dirname(title)?;
    let talk_path = parent.join(&dirname);
    if talk_path.exists() {
        return Err(format!("Directory {} already exists", talk_path.display()).into());
    }
    std::fs::create_dir(&talk_path)?;
    std::fs::write(talk_path.join("README.md"), readme_skeleton(title, venue))?;
    std::fs::write(
        talk_path.join("pre-setup.sh"),
        pre_setup_script_skeleton(venue)?,
    )?;
    for n in 1..=steps {
        let step_path = talk_path.join(format!("{n}-TODO"));
        std::fs::create_dir(&step_path)?;
        let setup_path = step_path.join("setup.sh");
        let cleanup_path = step_path.join("cleanup.sh");
        std::fs::write(&setup_path, setup_script_skeleton())?;
        std::fs::write(&cleanup_path, setup_script_skeleton())?;

        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let perms = std::fs::Permissions::from_mode(0o755);
            std::fs::set_permissions(&setup_path, perms.clone())?;
            std::fs::set_permissions(&cleanup_path, perms)?;
        }
    }
    Ok(talk_path)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn passthrough_single_word() {
        let got = title_to_dirname("Foo").unwrap();
        assert_eq!(got, "Foo");
    }

    #[test]
    fn replaces_spaces_with_dashes() {
        let got = title_to_dirname("Foo Bar").unwrap();
        assert_eq!(got, "Foo-Bar");
    }

    #[test]
    fn drops_punctuation() {
        let got = title_to_dirname("Foo: Bar").unwrap();
        assert_eq!(got, "Foo-Bar");
    }

    #[test]
    fn collapse_consecutive_dashes() {
        let got = title_to_dirname("Foo :: Bar").unwrap();
        assert_eq!(got, "Foo-Bar");
    }

    #[test]
    fn trims_trailing_and_leading_dashes() {
        let got = title_to_dirname(" Foo ").unwrap();
        assert_eq!(got, "Foo");
    }

    #[test]
    fn errors_on_empty_result() {
        let result = title_to_dirname("!!!");
        assert!(result.is_err());
    }

    #[test]
    fn readme_skeleton_matches_fixtures() {
        let got = readme_skeleton("My Talk", None);
        let expected = "# My Talk\n\n## Abstract\n\nTODO\n\n## Presented at\n\n- TODO:Date @ [TODO:Venue](TODO:URL)\n";
        assert_eq!(got, expected);
    }

    #[test]
    fn readme_skeleton_substitutes_venue() {
        let got = readme_skeleton("My Talk", Some("KCD Budapest"));
        assert!(got.contains("[KCD Budapest]"));
        assert!(!got.contains("TODO:Venue"));
    }

    #[test]
    fn pre_setup_script_skeleton_without_venue_keeps_placeholder() {
        let got = pre_setup_script_skeleton(None).unwrap();
        assert!(got.contains(r#"CLUSTER_NAME="TODO-CLUSTER""#));
    }

    #[test]
    fn pre_setup_script_skeleton_with_venue_uses_slug() {
        let got = pre_setup_script_skeleton(Some("KCD Budapest")).unwrap();
        assert!(got.contains(r#"CLUSTER_NAME="kcd-budapest""#));
        assert!(!got.contains("TODO-CLUSTER"));
    }

    #[test]
    fn setup_script_skeleton_has_shebang_and_preamble() {
        let got = setup_script_skeleton();
        assert!(got.starts_with("#!/bin/bash"));
        assert!(got.contains("SCRIPT_DIR="));
        assert!(got.ends_with("# TODO: implement\n"));
    }

    #[test]
    fn creates_talk_dir_with_dashed_name() {
        let tmp = tempfile::tempdir().unwrap();
        let talk_path = create_talk_dir(tmp.path(), "Foo Bar", None, 0).unwrap();
        assert!(talk_path.is_dir());
        assert_eq!(talk_path.file_name().unwrap(), "Foo-Bar");
    }

    #[test]
    fn writes_readme_inside_talk_dir() {
        let tmp = tempfile::tempdir().unwrap();
        let talk_path = create_talk_dir(tmp.path(), "My Talk", None, 0).unwrap();
        let readme = std::fs::read_to_string(talk_path.join("README.md")).unwrap();
        assert!(readme.starts_with("# My Talk\n"));
        assert!(readme.contains("## Abstract"));
        assert!(readme.contains("## Presented at"));
    }

    #[test]
    fn creates_step_subdirs_with_scripts() {
        let tmp = tempfile::tempdir().unwrap();
        let talk_path = create_talk_dir(tmp.path(), "My Talk", None, 3).unwrap();
        for n in 1..=3 {
            let step = talk_path.join(format!("{n}-TODO"));
            assert!(step.is_dir(), "step {n} dir should exist");
            assert!(
                step.join("setup.sh").is_file(),
                "setup.sh missing in step {n}"
            );
            assert!(
                step.join("cleanup.sh").is_file(),
                "cleanup.sh missing in step {n}"
            );
        }
    }

    #[test]
    #[cfg(unix)]
    fn scripts_are_executable() {
        use std::os::unix::fs::PermissionsExt;
        let tmp = tempfile::tempdir().unwrap();
        let talk_path = create_talk_dir(tmp.path(), "My Talk", None, 1).unwrap();
        let setup = talk_path.join("1-TODO/setup.sh");
        let mode = std::fs::metadata(&setup).unwrap().permissions().mode();
        assert!(
            mode & 0o111 != 0,
            "setup.sh not executable, mode was {mode:o}"
        );
    }

    #[test]
    fn errors_if_talk_dir_already_exists() {
        let tmp = tempfile::tempdir().unwrap();
        create_talk_dir(tmp.path(), "My Talk", None, 0).unwrap();
        let err = create_talk_dir(tmp.path(), "My Talk", None, 0).unwrap_err();
        let msg = format!("{err}");
        assert!(msg.contains("already exists"), "got: {msg}");
    }

    #[test]
    fn parse_args_title_only() {
        let args = vec!["scaff".to_string(), "My Talk".to_string()];
        let cli = parse_args(&args).unwrap();
        assert_eq!(cli.title, "My Talk");
        assert_eq!(cli.venue, None);
        assert_eq!(cli.steps, 0);
    }

    #[test]
    fn parse_args_with_steps_flag() {
        let args = vec![
            "scaff".to_string(),
            "My Talk".to_string(),
            "--steps".to_string(),
            "3".to_string(),
        ];
        let cli = parse_args(&args).unwrap();
        assert_eq!(cli.title, "My Talk");
        assert_eq!(cli.venue, None);
        assert_eq!(cli.steps, 3);
    }

    #[test]
    fn parse_args_with_venue_flag() {
        let args = vec![
            "scaff".to_string(),
            "My Talk".to_string(),
            "--venue".to_string(),
            "KCD Budapest".to_string(),
        ];
        let cli = parse_args(&args).unwrap();
        assert_eq!(cli.title, "My Talk");
        assert_eq!(cli.venue.as_deref(), Some("KCD Budapest"));
    }

    #[test]
    fn parse_args_empty_venue_becomes_none() {
        let args = vec![
            "scaff".to_string(),
            "My Talk".to_string(),
            "--venue".to_string(),
            String::new(),
        ];
        let cli = parse_args(&args).unwrap();
        assert_eq!(cli.venue, None);
    }

    #[test]
    fn parse_args_missing_title_errors() {
        let args = vec!["scaff".to_string()];
        assert!(parse_args(&args).is_err());
    }
}
