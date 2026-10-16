#!/usr/bin/env python3
"""Install a supplied local manifest, refusing to replace an existing different file."""
import argparse
import xml.etree.ElementTree as ET
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('destination', type=Path)
args = parser.parse_args()
if ET.parse(args.source).getroot().tag != 'manifest':
    parser.error('Expected a repo <manifest> document')
data = args.source.read_bytes()
if args.destination.exists() and args.destination.read_bytes() != data:
    parser.error(f'{args.destination} differs: review it manually; refusing to overwrite')
args.destination.parent.mkdir(parents=True, exist_ok=True)
args.destination.write_bytes(data)
