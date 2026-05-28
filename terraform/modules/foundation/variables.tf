variable "project_name" {
  type = string
}

variable "embedding_model_id" {
  type = string
}

variable "python_bin" {
  type        = string
  description = "Python interpreter with boto3 (use repo .venv)"
}

variable "scripts_dir" {
  type        = string
  description = "Absolute path to the scripts/ directory"
}

variable "seed_data_dir" {
  type        = string
  description = "Absolute path to the seed-data/ directory"
}
