import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import uuid

from k2up.emark import validate_record, validate_bank, sample_record, sample_bank
from k2up.picture import resource_for, sha
from k2up.gui_bridge import main


class EmarkTests(unittest.TestCase):
    def test_uninitialized_bank_has_actionable_message_without_accepting_corruption(self):
        for header in (b'\x00' * 4, b'\xff' * 4):
            raw = header + b'\xff' * (666 - 4)
            with self.assertRaisesRegex(ValueError, "设备尚未保存自定义 E-Mark 配置。内置档位不在本次读取范围内"):
                validate_bank(raw)
            damaged = bytearray(raw); damaged[6] = 0
            with self.assertRaisesRegex(ValueError, "配置数量或默认组无效"):
                validate_bank(damaged)
        self.assertEqual(validate_bank(b'\xff' * 4 + b'\x00\x00' + b'\xff' * 660)[5], 0)

    def test_read_uninitialized_bank_preserves_raw_backup_and_does_not_write(self):
        from k2up.firmware import APP_START
        from k2up.gui_bridge import Events
        from k2up.picture_device import transfer_resource, load_backup
        from k2up.picture_simulator import PictureTransport
        from k2up.protocol import Protocol
        from k2up.updater import Updater

        transport = PictureTransport()
        protocol = Protocol(transport)
        identity = Updater(protocol).probe()
        resource = resource_for('emark')
        original = b'\x00' * 4 + b'\xff' * (resource.allocation - 4)
        offset = resource.address - APP_START
        transport.memory[offset:offset + resource.allocation] = original
        request = {'id': str(uuid.uuid4()), 'operation': 'resource-read', 'resource_kind': 'emark'}
        with tempfile.TemporaryDirectory() as root:
            directory = Path(root) / 'backup'
            result = transfer_resource(request, Events(request, io.StringIO()), protocol, identity, directory)
            self.assertFalse(result['resource_valid'])
            self.assertIn('设备尚未保存自定义 E-Mark 配置。内置档位不在本次读取范围内', result['resource_error'])
            self.assertEqual(Path(result['resource_path']).read_bytes(), original[:resource.size])
            _, raw, metadata = load_backup(directory / 'manifest.json')
            self.assertEqual(raw, original)
            self.assertTrue(metadata['two_reads_match'])
        self.assertFalse(transport.erased)
        self.assertFalse(any(packet.command in (8, 9, 23) for packet in transport.sent))
        self.assertEqual(bytes(transport.memory[offset:offset + resource.allocation]), original)

    def test_exact_record_layout_and_checksum(self):
        data = sample_record("Cable A")
        self.assertEqual(len(data), 66)
        self.assertEqual(data[:8], b"Cable A\0")
        self.assertEqual(data[20], 2)
        self.assertEqual(data[65], (sum(data[:65]) + 165) % 256)
        for index in (0, 19, 21, 37, 49, 61, 65):
            wrong = bytearray(data); wrong[index] ^= 1
            with self.assertRaises(ValueError): validate_record(wrong)

    def test_bounds_and_unsupported_version(self):
        for size in (0, 65, 67):
            with self.assertRaises(ValueError): validate_record(bytes(size))
        data = bytearray(sample_record()); data[20] = 1
        data[65] = (sum(data[:65]) + 165) % 256
        self.assertEqual(validate_record(data)[20], 1)
        for mutation in ("name", "pd"):
            data = bytearray(sample_record())
            if mutation == "name": data[:19] = b"A" * 19
            else: data[20] = 4
            data[65] = (sum(data[:65]) + 165) % 256
            with self.assertRaises(ValueError): validate_record(data)

    def test_bank_preserves_unknown_header_and_inactive_slots(self):
        data = bytearray(sample_bank()); data[:4] = b"abcd"
        data[72:] = bytes((i * 17) % 256 for i in range(594))
        self.assertEqual(validate_bank(data), data)
        for selected, count in ((10, 10), (0, 11), (1, 0), (1, 1)):
            wrong = bytearray(data); wrong[4:6] = bytes((selected, count))
            with self.assertRaises(ValueError): validate_bank(wrong)
        data[4:6] = bytes((0, 0)); self.assertEqual(validate_bank(data), data)

    def test_all_ten_active_records_require_valid_checksums(self):
        data = bytearray(sample_bank()); data[4:6] = bytes((9, 10))
        for i in range(10): data[6 + i * 66:72 + i * 66] = sample_record(f"Cable {i}")
        validate_bank(data)
        data[6 + 9 * 66 + 65] ^= 1
        with self.assertRaises(ValueError): validate_bank(data)

    def test_fixed_emark_ranges_end_at_layout_and_do_not_overlap(self):
        copied, bank, layout = (resource_for(kind) for kind in ("emark-copy", "emark", "layout"))
        self.assertEqual((copied.address, copied.size, copied.allocation), (0x080E3000, 66, 2048))
        self.assertEqual((bank.address, bank.size, bank.allocation), (0x080E3800, 666, 2048))
        self.assertEqual(copied.address + copied.allocation, bank.address)
        self.assertEqual(bank.address + bank.allocation, layout.address)

    def test_bridge_invalid_configuration_is_rejected_before_usb(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / "invalid.resource"
            raw = bytearray(sample_bank()); raw[5] = 11; path.write_bytes(raw)
            request = {"id": str(uuid.uuid4()), "operation": "resource-write", "resource_kind": "emark",
                       "simulation": False, "data_directory": root, "resource_path": str(path),
                       "resource_sha256": sha(raw), "dfu_confirmed": True, "device_path_hex": "00",
                       "device_info_sha256": "device", "confirmed": True}
            output = io.StringIO()
            with patch("k2up.transport._hid", side_effect=AssertionError("USB accessed")):
                code = main(io.StringIO(json.dumps(request) + "\n"), output)
            self.assertEqual(code, 1)
            self.assertIn("默认组", output.getvalue())


if __name__ == "__main__": unittest.main()
