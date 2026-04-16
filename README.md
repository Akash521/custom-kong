"""
ORM Models for NRD Schema — fully aligned with root_nrd.xsd, xsd_tech.xsd,
xsd_tact.xsd, nrd_types.xsd.

Design decisions:
  - entity_id is the logical primary key (unique per entity across all uploads).
  - UPSERT on entity_id prevents duplicates.
  - upload_id (SET NULL on delete) tracks last upload that wrote each row.
  - Multi-valued link tables (ContactsLink, SeekerLink, EquipmentLink, etc.)
    use dedicated child tables.
  - Cross-domain tactical→technical links stored as tech_*_entity_id strings
    (viewonly ORM relationships resolve them at query time).
  - ROOT header fields (Name, CreationDate, Comment) added to upload_log.
  - Alias/Introduction added to all tech entities.
  - Spurious fields (unit_type, force, strength, status, circular_range)
    that were NOT in the XSD have been removed.
"""
from datetime import datetime
from typing import Optional, List
import enum

from sqlalchemy import (
    Boolean, DateTime, Double, Float, ForeignKey,
    Integer, LargeBinary, String, Text, UniqueConstraint
)
from sqlalchemy.orm import relationship, Mapped, mapped_column

from app.core.database import Base


# ---------------------------------------------------------------------------
# UPLOAD LOG
# ---------------------------------------------------------------------------

class UploadLog(Base):
    __tablename__ = "upload_log"

    id: Mapped[int]               = mapped_column(Integer, primary_key=True, autoincrement=True)
    filename: Mapped[str]         = mapped_column(String(255))
    exchange_type: Mapped[Optional[str]] = mapped_column(String(20))
    schema_version: Mapped[Optional[str]] = mapped_column(String(50))
    file_hash: Mapped[Optional[str]] = mapped_column(String(64), index=True)
    # ROOT header fields
    root_name: Mapped[Optional[str]] = mapped_column(String(255))
    root_creation_date: Mapped[Optional[str]] = mapped_column(String(50))
    root_comment: Mapped[Optional[str]] = mapped_column(String(1000))
    is_valid: Mapped[bool]        = mapped_column(Boolean, default=False)
    validation_errors: Mapped[Optional[str]] = mapped_column(Text)
    uploaded_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    processed_at: Mapped[Optional[datetime]] = mapped_column(DateTime)

    attachments: Mapped[List["Attachment"]] = relationship(
        "Attachment", back_populates="upload", cascade="all, delete-orphan"
    )


class Attachment(Base):
    __tablename__ = "attachment"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[int] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="CASCADE"))
    filename: Mapped[str]  = mapped_column(String(255))
    mime_type: Mapped[Optional[str]] = mapped_column(String(100))
    file_size: Mapped[Optional[int]] = mapped_column(Integer)
    data: Mapped[bytes]    = mapped_column(LargeBinary)

    upload: Mapped["UploadLog"] = relationship("UploadLog", back_populates="attachments")


# ---------------------------------------------------------------------------
# TECHNICAL — abstract base fields shared as mixin (not a real table)
# Every tech entity has: entity_id, object_id, reference_date,
# modification_date, state, english_name, name, alias_json (JSON array),
# introduction, comments, environment
# ---------------------------------------------------------------------------

class TechCountry(Base):
    __tablename__ = "tech_country"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    object_id: Mapped[Optional[str]] = mapped_column(String(255))
    state: Mapped[Optional[str]] = mapped_column(String(255), default="Unmodified")
    english_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[Optional[str]] = mapped_column(String(255))
    country_code: Mapped[Optional[str]] = mapped_column(String(20))
    source: Mapped[str]    = mapped_column(String(255))
    affiliation: Mapped[Optional[str]] = mapped_column(String(20))   # HostilityType


class TechPlatform(Base):
    __tablename__ = "tech_platform"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    object_id: Mapped[Optional[str]] = mapped_column(String(255))
    reference_date: Mapped[Optional[str]] = mapped_column(String(50))
    modification_date: Mapped[Optional[str]] = mapped_column(String(50))
    state: Mapped[str]     = mapped_column(String(20), default="Unmodified")
    english_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[Optional[str]] = mapped_column(String(255))
    alias_json: Mapped[Optional[str]] = mapped_column(Text)           # JSON array of aliases
    introduction: Mapped[Optional[str]] = mapped_column(Text)
    comments: Mapped[Optional[str]] = mapped_column(String(1000))
    environment: Mapped[Optional[str]] = mapped_column(String(100))   # comma-separated
    classification: Mapped[str] = mapped_column(String(255))
    platform_type: Mapped[str] = mapped_column(String(255))
    manufacturer: Mapped[str] = mapped_column(String(255))
    source: Mapped[str]    = mapped_column(String(255))
    country: Mapped[Optional[str]] = mapped_column(String(255))
    max_detection_range: Mapped[str]  = mapped_column(String(50), default="N/A")
    max_engagement_range: Mapped[str] = mapped_column(String(50), default="N/A")
    max_firing_range: Mapped[str]     = mapped_column(String(50), default="N/A")
    # CountryLink (single, stored inline — LinkCountryType extends LinkType)
    country_link_dest_class: Mapped[Optional[str]]          = mapped_column(String(100))
    country_link_dest_id: Mapped[Optional[str]]             = mapped_column(String(50))
    country_link_att1: Mapped[Optional[str]]                = mapped_column(String(100))
    country_link_att2: Mapped[Optional[str]]                = mapped_column(String(100))
    country_link_att3: Mapped[Optional[str]]                = mapped_column(String(100))
    country_link_start_date: Mapped[Optional[str]]          = mapped_column(String(50))
    country_link_end_date: Mapped[Optional[str]]            = mapped_column(String(50))
    country_link_manufacturing_plant: Mapped[Optional[str]] = mapped_column(String(255))
    country_link_export_approval: Mapped[Optional[str]]     = mapped_column(String(255))
    # TacticalPlatformLink (TacticalLinkType: ID, Class, MappingType, ConfidenceLevel, ATT_1, ATT_2, StartDate)
    tact_platform_link_id: Mapped[Optional[str]]         = mapped_column(String(50))
    tact_platform_link_class: Mapped[Optional[str]]      = mapped_column(String(100))
    tact_platform_link_mapping: Mapped[Optional[str]]    = mapped_column(String(50))
    tact_platform_link_confidence: Mapped[Optional[str]] = mapped_column(String(20))
    tact_platform_link_att1: Mapped[Optional[str]]       = mapped_column(String(100))
    tact_platform_link_att2: Mapped[Optional[str]]       = mapped_column(String(100))
    tact_platform_link_start_date: Mapped[Optional[str]] = mapped_column(String(50))

    equipment_links: Mapped[List["TechEquipmentLink"]] = relationship(
        "TechEquipmentLink",
        primaryjoin="and_(TechEquipmentLink.parent_entity_type=='Platform', foreign(TechEquipmentLink.parent_entity_id)==TechPlatform.entity_id)",
        viewonly=True,
    )
    instances: Mapped[List["TechPlatformInstance"]] = relationship(
        "TechPlatformInstance",
        primaryjoin="foreign(TechPlatformInstance.platform_class_dest_id)==TechPlatform.entity_id",
        back_populates="platform_class", viewonly=True,
    )
    tact_instances: Mapped[List["TactPlatformInstance"]] = relationship(
        "TactPlatformInstance",
        primaryjoin="foreign(TactPlatformInstance.tech_platform_entity_id)==TechPlatform.entity_id",
        back_populates="tech_platform", viewonly=True,
    )


class TechPlatformInstance(Base):
    __tablename__ = "tech_platform_instance"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    object_id: Mapped[Optional[str]] = mapped_column(String(255))
    reference_date: Mapped[Optional[str]] = mapped_column(String(50))
    modification_date: Mapped[Optional[str]] = mapped_column(String(50))
    state: Mapped[str]     = mapped_column(String(20), default="Unmodified")
    english_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[Optional[str]] = mapped_column(String(255))
    alias_json: Mapped[Optional[str]] = mapped_column(Text)
    introduction: Mapped[Optional[str]] = mapped_column(Text)
    comments: Mapped[Optional[str]] = mapped_column(String(1000))
    environment: Mapped[Optional[str]] = mapped_column(String(100))
    # PlatformClassLink
    platform_class_dest_id: Mapped[Optional[str]]    = mapped_column(String(50))
    platform_class_dest_class: Mapped[Optional[str]] = mapped_column(String(100))
    platform_class_inheritance: Mapped[Optional[str]] = mapped_column(String(50))
    platform_class_version: Mapped[Optional[str]]    = mapped_column(String(100))
    platform_class_modifications: Mapped[Optional[str]] = mapped_column(String(255))
    platform_class_att1: Mapped[Optional[str]] = mapped_column(String(100))
    platform_class_att2: Mapped[Optional[str]] = mapped_column(String(100))
    platform_class_att3: Mapped[Optional[str]] = mapped_column(String(100))
    platform_class_start_date: Mapped[Optional[str]] = mapped_column(String(50))
    platform_class_end_date: Mapped[Optional[str]]   = mapped_column(String(50))
    # TacticalPlatformLink (TacticalLinkType: ID, Class, MappingType, ConfidenceLevel, ATT_1, ATT_2, StartDate)
    tact_platform_link_id: Mapped[Optional[str]]         = mapped_column(String(50))
    tact_platform_link_class: Mapped[Optional[str]]      = mapped_column(String(100))
    tact_platform_link_mapping: Mapped[Optional[str]]    = mapped_column(String(50))
    tact_platform_link_confidence: Mapped[Optional[str]] = mapped_column(String(20))
    tact_platform_link_att1: Mapped[Optional[str]]       = mapped_column(String(100))
    tact_platform_link_att2: Mapped[Optional[str]]       = mapped_column(String(100))
    tact_platform_link_start_date: Mapped[Optional[str]] = mapped_column(String(50))

    platform_class: Mapped[Optional["TechPlatform"]] = relationship(
        "TechPlatform",
        primaryjoin="foreign(TechPlatformInstance.platform_class_dest_id)==TechPlatform.entity_id",
        back_populates="instances", viewonly=True,
    )
    radar_instances: Mapped[List["TechRadarInstance"]] = relationship(
        "TechRadarInstance",
        primaryjoin="foreign(TechRadarInstance.platform_instance_dest_id)==TechPlatformInstance.entity_id",
        back_populates="platform_instance", viewonly=True,
    )
    tact_instances: Mapped[List["TactPlatformInstance"]] = relationship(
        "TactPlatformInstance",
        primaryjoin="foreign(TactPlatformInstance.tech_platform_instance_entity_id)==TechPlatformInstance.entity_id",
        back_populates="tech_platform_instance", viewonly=True,
    )


class TechRadar(Base):
    __tablename__ = "tech_radar"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    object_id: Mapped[Optional[str]] = mapped_column(String(255))
    reference_date: Mapped[Optional[str]] = mapped_column(String(50))
    modification_date: Mapped[Optional[str]] = mapped_column(String(50))
    state: Mapped[str]     = mapped_column(String(20), default="Unmodified")
    english_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[Optional[str]] = mapped_column(String(255))
    alias_json: Mapped[Optional[str]] = mapped_column(Text)
    introduction: Mapped[Optional[str]] = mapped_column(Text)
    comments: Mapped[Optional[str]] = mapped_column(String(1000))
    environment: Mapped[Optional[str]] = mapped_column(String(100))
    classification: Mapped[str] = mapped_column(String(255))
    function: Mapped[str]  = mapped_column(String(255))
    manufacturer: Mapped[str] = mapped_column(String(255))
    source: Mapped[str]    = mapped_column(String(255))
    country: Mapped[Optional[str]] = mapped_column(String(255))
    polarisation: Mapped[Optional[str]] = mapped_column(String(100))
    radar_code: Mapped[str] = mapped_column(String(50), default="N/A")
    elnot: Mapped[str]     = mapped_column(String(50), default="N/A")
    # CountryLink (single inline — LinkCountryType extends LinkType)
    country_link_dest_class: Mapped[Optional[str]]          = mapped_column(String(100))
    country_link_dest_id: Mapped[Optional[str]]             = mapped_column(String(50))
    country_link_att1: Mapped[Optional[str]]                = mapped_column(String(100))
    country_link_att2: Mapped[Optional[str]]                = mapped_column(String(100))
    country_link_att3: Mapped[Optional[str]]                = mapped_column(String(100))
    country_link_start_date: Mapped[Optional[str]]          = mapped_column(String(50))
    country_link_end_date: Mapped[Optional[str]]            = mapped_column(String(50))
    country_link_manufacturing_plant: Mapped[Optional[str]] = mapped_column(String(255))
    country_link_export_approval: Mapped[Optional[str]]     = mapped_column(String(255))
    # TacticalRadarLink (TacticalLinkType: ID, Class, MappingType, ConfidenceLevel, ATT_1, ATT_2, StartDate)
    tact_radar_link_id: Mapped[Optional[str]]         = mapped_column(String(50))
    tact_radar_link_class: Mapped[Optional[str]]      = mapped_column(String(100))
    tact_radar_link_mapping: Mapped[Optional[str]]    = mapped_column(String(50))
    tact_radar_link_confidence: Mapped[Optional[str]] = mapped_column(String(20))
    tact_radar_link_att1: Mapped[Optional[str]]       = mapped_column(String(100))
    tact_radar_link_att2: Mapped[Optional[str]]       = mapped_column(String(100))
    tact_radar_link_start_date: Mapped[Optional[str]] = mapped_column(String(50))

    modes: Mapped[List["TechMode"]] = relationship(
        "TechMode", back_populates="radar", cascade="all, delete-orphan"
    )
    seeker_links: Mapped[List["TechRadarSeekerLink"]] = relationship(
        "TechRadarSeekerLink", back_populates="radar", cascade="all, delete-orphan"
    )
    instances: Mapped[List["TechRadarInstance"]] = relationship(
        "TechRadarInstance",
        primaryjoin="foreign(TechRadarInstance.radar_class_dest_id)==TechRadar.entity_id",
        back_populates="radar_class", viewonly=True,
    )
    tact_instances: Mapped[List["TactRadarInstance"]] = relationship(
        "TactRadarInstance",
        primaryjoin="foreign(TactRadarInstance.tech_radar_entity_id)==TechRadar.entity_id",
        back_populates="tech_radar", viewonly=True,
    )


class TechRadarSeekerLink(Base):
    """SeekerLink on tech:Radar (0..unbounded). Links Radar to Seeker entity."""
    __tablename__ = "tech_radar_seeker_link"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    radar_id: Mapped[int]  = mapped_column(Integer, ForeignKey("tech_radar.id", ondelete="CASCADE"))
    # LinkSeekerType base fields
    dest_class: Mapped[Optional[str]] = mapped_column(String(50))
    dest_id: Mapped[str]   = mapped_column(String(50))      # -> tech_seeker.entity_id
    att_1: Mapped[Optional[str]] = mapped_column(String(100))
    att_2: Mapped[Optional[str]] = mapped_column(String(100))
    att_3: Mapped[Optional[str]] = mapped_column(String(100))
    start_date: Mapped[Optional[str]] = mapped_column(String(50))
    end_date: Mapped[Optional[str]]   = mapped_column(String(50))
    # LinkSeekerType extension fields
    seeker_type: Mapped[Optional[str]]   = mapped_column(String(100))
    guidance_mode: Mapped[Optional[str]] = mapped_column(String(100))
    handover_time: Mapped[Optional[str]] = mapped_column(String(50))
    frequency_band: Mapped[Optional[str]] = mapped_column(String(50))
    range_val: Mapped[Optional[str]]     = mapped_column(String(50))

    radar: Mapped["TechRadar"] = relationship("TechRadar", back_populates="seeker_links")


class TechRadarInstance(Base):
    __tablename__ = "tech_radar_instance"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    object_id: Mapped[Optional[str]] = mapped_column(String(255))
    reference_date: Mapped[Optional[str]] = mapped_column(String(50))
    modification_date: Mapped[Optional[str]] = mapped_column(String(50))
    state: Mapped[str]     = mapped_column(String(20), default="Unmodified")
    english_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[Optional[str]] = mapped_column(String(255))
    alias_json: Mapped[Optional[str]] = mapped_column(Text)
    introduction: Mapped[Optional[str]] = mapped_column(Text)
    comments: Mapped[Optional[str]] = mapped_column(String(1000))
    environment: Mapped[Optional[str]] = mapped_column(String(100))
    # RadarClassLink (LinkRadarClassType)
    radar_class_dest_id: Mapped[Optional[str]]       = mapped_column(String(50))
    radar_class_dest_class: Mapped[Optional[str]]    = mapped_column(String(100))
    radar_class_inheritance: Mapped[Optional[str]]   = mapped_column(String(50))
    radar_class_version: Mapped[Optional[str]]       = mapped_column(String(100))
    radar_class_configuration: Mapped[Optional[str]] = mapped_column(String(255))
    radar_class_att1: Mapped[Optional[str]] = mapped_column(String(100))
    radar_class_att2: Mapped[Optional[str]] = mapped_column(String(100))
    radar_class_att3: Mapped[Optional[str]] = mapped_column(String(100))
    radar_class_start_date: Mapped[Optional[str]] = mapped_column(String(50))
    radar_class_end_date: Mapped[Optional[str]]   = mapped_column(String(50))
    # PlatformInstanceLink (LinkRadarPlatformInstanceType)
    platform_instance_dest_id: Mapped[Optional[str]]         = mapped_column(String(50))
    platform_instance_dest_class: Mapped[Optional[str]]      = mapped_column(String(100))
    platform_instance_relationship: Mapped[Optional[str]]    = mapped_column(String(50))  # fixed 'InstalledOn'
    platform_instance_mount_location: Mapped[Optional[str]]  = mapped_column(String(255))
    platform_instance_installation_date: Mapped[Optional[str]] = mapped_column(String(50))
    platform_instance_att1: Mapped[Optional[str]] = mapped_column(String(100))
    platform_instance_att2: Mapped[Optional[str]] = mapped_column(String(100))
    platform_instance_att3: Mapped[Optional[str]] = mapped_column(String(100))
    platform_instance_start_date: Mapped[Optional[str]] = mapped_column(String(50))
    platform_instance_end_date: Mapped[Optional[str]]   = mapped_column(String(50))
    # TacticalRadarLink (TacticalLinkType: ID, Class, MappingType, ConfidenceLevel, ATT_1, ATT_2, StartDate)
    tact_radar_link_id: Mapped[Optional[str]]         = mapped_column(String(50))
    tact_radar_link_class: Mapped[Optional[str]]      = mapped_column(String(100))
    tact_radar_link_mapping: Mapped[Optional[str]]    = mapped_column(String(50))
    tact_radar_link_confidence: Mapped[Optional[str]] = mapped_column(String(20))
    tact_radar_link_att1: Mapped[Optional[str]]       = mapped_column(String(100))
    tact_radar_link_att2: Mapped[Optional[str]]       = mapped_column(String(100))
    tact_radar_link_start_date: Mapped[Optional[str]] = mapped_column(String(50))

    radar_class: Mapped[Optional["TechRadar"]] = relationship(
        "TechRadar",
        primaryjoin="foreign(TechRadarInstance.radar_class_dest_id)==TechRadar.entity_id",
        back_populates="instances", viewonly=True,
    )
    platform_instance: Mapped[Optional["TechPlatformInstance"]] = relationship(
        "TechPlatformInstance",
        primaryjoin="foreign(TechRadarInstance.platform_instance_dest_id)==TechPlatformInstance.entity_id",
        back_populates="radar_instances", viewonly=True,
    )
    tact_instances: Mapped[List["TactRadarInstance"]] = relationship(
        "TactRadarInstance",
        primaryjoin="foreign(TactRadarInstance.tech_radar_instance_entity_id)==TechRadarInstance.entity_id",
        back_populates="tech_radar_instance", viewonly=True,
    )


class TechMode(Base):
    __tablename__ = "tech_mode"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    radar_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("tech_radar.id", ondelete="CASCADE"))
    entity_id: Mapped[str] = mapped_column(String(50))
    name: Mapped[str]      = mapped_column(String(255))
    source: Mapped[str]    = mapped_column(String(255))
    modulation_type: Mapped[str] = mapped_column(String(100))
    modulation_info: Mapped[Optional[str]] = mapped_column(String(255))
    multifunction: Mapped[str] = mapped_column(String(5), default="No")
    phase: Mapped[Optional[str]] = mapped_column(String(100))
    emission_function: Mapped[Optional[str]] = mapped_column(String(100))
    scan_type: Mapped[Optional[str]] = mapped_column(String(100))

    radar: Mapped[Optional["TechRadar"]] = relationship("TechRadar", back_populates="modes")
    waveforms: Mapped[List["TechWaveform"]] = relationship(
        "TechWaveform", back_populates="mode", cascade="all, delete-orphan"
    )

    __table_args__ = (UniqueConstraint("radar_id", "entity_id", name="uq_tech_mode_radar_entity"),)


class TechWaveform(Base):
    __tablename__ = "tech_waveform"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    mode_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("tech_mode.id", ondelete="CASCADE"))
    entity_id: Mapped[str] = mapped_column(String(50))
    name: Mapped[str]      = mapped_column(String(255))
    source: Mapped[str]    = mapped_column(String(255))
    # IntrapulseModulation
    intrapulse_summary: Mapped[Optional[str]] = mapped_column(Text)
    # FrequencyLevel
    center_frequency: Mapped[Optional[str]] = mapped_column(String(50))
    freq_min: Mapped[Optional[float]] = mapped_column(Float)
    freq_max: Mapped[Optional[float]] = mapped_column(Float)
    freq_mean: Mapped[Optional[float]] = mapped_column(Float)
    freq_stddev: Mapped[Optional[float]] = mapped_column(Float)
    # PWLevel
    pulse_width: Mapped[Optional[str]] = mapped_column(String(50))
    pw_min: Mapped[Optional[float]] = mapped_column(Float)
    pw_max: Mapped[Optional[float]] = mapped_column(Float)
    pw_mean: Mapped[Optional[float]] = mapped_column(Float)
    # PRILevel
    pri: Mapped[Optional[str]] = mapped_column(String(50))
    pri_min: Mapped[Optional[float]] = mapped_column(Float)
    pri_max: Mapped[Optional[float]] = mapped_column(Float)
    pri_mean: Mapped[Optional[float]] = mapped_column(Float)
    pri_agility: Mapped[Optional[str]] = mapped_column(String(100))

    mode: Mapped[Optional["TechMode"]] = relationship("TechMode", back_populates="waveforms")
    fap_elements: Mapped[List["TechFAPElement"]] = relationship(
        "TechFAPElement", back_populates="waveform", cascade="all, delete-orphan"
    )

    __table_args__ = (UniqueConstraint("mode_id", "entity_id", name="uq_tech_waveform_mode_entity"),)


class TechFAPElement(Base):
    """FAPElement inside IntrapulseModulation of a Waveform (0..unbounded)."""
    __tablename__ = "tech_fap_element"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    waveform_id: Mapped[int] = mapped_column(Integer, ForeignKey("tech_waveform.id", ondelete="CASCADE"))
    seq: Mapped[int]       = mapped_column(Integer)          # order within waveform
    pattern_name: Mapped[Optional[str]]  = mapped_column(String(255))
    start_frequency: Mapped[Optional[float]] = mapped_column(Float)
    end_frequency: Mapped[Optional[float]]   = mapped_column(Float)
    phase_coding: Mapped[Optional[str]]      = mapped_column(String(100))
    phase_degrees: Mapped[Optional[float]]   = mapped_column(Float)
    amplitude_db: Mapped[Optional[float]]    = mapped_column(Float)
    time_offset_us: Mapped[Optional[float]]  = mapped_column(Float)
    duration_us: Mapped[Optional[float]]     = mapped_column(Float)
    comments: Mapped[Optional[str]]          = mapped_column(String(1000))

    waveform: Mapped["TechWaveform"] = relationship("TechWaveform", back_populates="fap_elements")


class TechEquipmentLink(Base):
    """
    Generic EquipmentLink used by Platform, PlatformInstance, WeaponSystem.
    parent_entity_type: 'Platform' | 'PlatformInstance' | 'WeaponSystem'
    parent_entity_id: entity_id of the parent.
    """
    __tablename__ = "tech_equipment_link"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    parent_entity_type: Mapped[str] = mapped_column(String(50))
    parent_entity_id: Mapped[str]   = mapped_column(String(50))
    dest_class: Mapped[Optional[str]] = mapped_column(String(50))
    dest_id: Mapped[str]   = mapped_column(String(50))
    att_1: Mapped[Optional[str]] = mapped_column(String(100))
    att_2: Mapped[Optional[str]] = mapped_column(String(100))
    att_3: Mapped[Optional[str]] = mapped_column(String(100))
    start_date: Mapped[Optional[str]] = mapped_column(String(50))
    end_date: Mapped[Optional[str]]   = mapped_column(String(50))
    # LinkPlatformEquipmentTechType extension (Platform/PlatformInstance)
    quantity: Mapped[Optional[int]]           = mapped_column(Integer)
    mount_location: Mapped[Optional[str]]     = mapped_column(String(255))
    power_requirement: Mapped[Optional[str]]  = mapped_column(String(50))
    # LinkWeaponEquipmentType extension (WeaponSystem) — additional fields
    configuration: Mapped[Optional[str]]      = mapped_column(String(255))
    integration_level: Mapped[Optional[str]]  = mapped_column(String(100))


class TechWeaponSystem(Base):
    __tablename__ = "tech_weapon_system"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    object_id: Mapped[Optional[str]] = mapped_column(String(255))
    reference_date: Mapped[Optional[str]] = mapped_column(String(50))
    modification_date: Mapped[Optional[str]] = mapped_column(String(50))
    state: Mapped[str]     = mapped_column(String(20), default="Unmodified")
    english_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[Optional[str]] = mapped_column(String(255))
    alias_json: Mapped[Optional[str]] = mapped_column(Text)
    introduction: Mapped[Optional[str]] = mapped_column(Text)
    comments: Mapped[Optional[str]] = mapped_column(String(1000))
    environment: Mapped[Optional[str]] = mapped_column(String(100))
    classification: Mapped[str] = mapped_column(String(255))
    manufacturer: Mapped[str] = mapped_column(String(255))
    source: Mapped[str]    = mapped_column(String(255))
    country: Mapped[Optional[str]] = mapped_column(String(255))
    length: Mapped[str]    = mapped_column(String(50), default="N/A")
    width: Mapped[str]     = mapped_column(String(50), default="N/A")
    height: Mapped[str]    = mapped_column(String(50), default="N/A")
    max_range: Mapped[str] = mapped_column(String(50), default="N/A")
    max_speed: Mapped[str] = mapped_column(String(50), default="N/A")
    cruising_speed: Mapped[str] = mapped_column(String(50), default="N/A")
    service_ceiling: Mapped[str] = mapped_column(String(50), default="N/A")

    platform_links: Mapped[List["TechWeaponPlatformLink"]] = relationship(
        "TechWeaponPlatformLink", back_populates="weapon_system", cascade="all, delete-orphan"
    )
    child_links: Mapped[List["TechWeaponSystemChildLink"]] = relationship(
        "TechWeaponSystemChildLink", back_populates="weapon_system", cascade="all, delete-orphan"
    )
    tact_weapons: Mapped[List["TactWeapon"]] = relationship(
        "TactWeapon",
        primaryjoin="foreign(TactWeapon.tech_weapon_entity_id)==TechWeaponSystem.entity_id",
        back_populates="tech_weapon_system", viewonly=True,
    )


class TechWeaponPlatformLink(Base):
    """PlatformLink on tech:WeaponSystem (0..unbounded)."""
    __tablename__ = "tech_weapon_platform_link"

    id: Mapped[int]              = mapped_column(Integer, primary_key=True, autoincrement=True)
    weapon_system_id: Mapped[int] = mapped_column(Integer, ForeignKey("tech_weapon_system.id", ondelete="CASCADE"))
    dest_class: Mapped[Optional[str]] = mapped_column(String(50))
    dest_id: Mapped[str]         = mapped_column(String(50))
    att_1: Mapped[Optional[str]] = mapped_column(String(100))
    att_2: Mapped[Optional[str]] = mapped_column(String(100))
    att_3: Mapped[Optional[str]] = mapped_column(String(100))
    start_date: Mapped[Optional[str]] = mapped_column(String(50))
    end_date: Mapped[Optional[str]]   = mapped_column(String(50))
    integration_date: Mapped[Optional[str]]    = mapped_column(String(50))
    number_of_launchers: Mapped[Optional[int]] = mapped_column(Integer)
    mount_type: Mapped[Optional[str]]          = mapped_column(String(100))
    compatibility: Mapped[Optional[str]]       = mapped_column(String(255))

    weapon_system: Mapped["TechWeaponSystem"] = relationship("TechWeaponSystem", back_populates="platform_links")


class TechWeaponSystemChildLink(Base):
    """
    Stores the nested equipment refs inside tech:WeaponSystem.
    XSD allows: ref:Radar, ref:RadarInstance, ref:Missile, ref:Gun,
                ref:Transceiver, ref:Laser, ref:PassiveSensor (0..unbounded each).
    child_type: 'Radar'|'RadarInstance'|'Missile'|'Gun'|'Transceiver'|'Laser'|'PassiveSensor'
    child_entity_id: entity_id of the referenced child entity
    """
    __tablename__ = "tech_weapon_system_child_link"

    id: Mapped[int]               = mapped_column(Integer, primary_key=True, autoincrement=True)
    weapon_system_id: Mapped[int] = mapped_column(Integer, ForeignKey("tech_weapon_system.id", ondelete="CASCADE"))
    child_type: Mapped[str]       = mapped_column(String(50))   # entity class name
    child_entity_id: Mapped[str]  = mapped_column(String(50))   # -> entity_id in respective table

    weapon_system: Mapped["TechWeaponSystem"] = relationship(
        "TechWeaponSystem", back_populates="child_links"
    )


class TechMissile(Base):
    __tablename__ = "tech_missile"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    object_id: Mapped[Optional[str]] = mapped_column(String(255))
    reference_date: Mapped[Optional[str]] = mapped_column(String(50))
    modification_date: Mapped[Optional[str]] = mapped_column(String(50))
    state: Mapped[str]     = mapped_column(String(20), default="Unmodified")
    english_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[Optional[str]] = mapped_column(String(255))
    alias_json: Mapped[Optional[str]] = mapped_column(Text)
    introduction: Mapped[Optional[str]] = mapped_column(Text)
    comments: Mapped[Optional[str]] = mapped_column(String(1000))
    environment: Mapped[Optional[str]] = mapped_column(String(100))
    weapon_code: Mapped[str] = mapped_column(String(50), default="N/A")
    classification: Mapped[str] = mapped_column(String(255))
    manufacturer: Mapped[str] = mapped_column(String(255))
    source: Mapped[str]    = mapped_column(String(255))
    country: Mapped[Optional[str]] = mapped_column(String(255))
    missile_type: Mapped[str] = mapped_column(String(255))
    missile_category: Mapped[str] = mapped_column(String(255))
    weapon_function: Mapped[str] = mapped_column(String(255))
    min_range: Mapped[str] = mapped_column(String(50), default="N/A")
    max_range: Mapped[str] = mapped_column(String(50), default="N/A")
    max_speed: Mapped[str] = mapped_column(String(50), default="N/A")
    min_target_height: Mapped[str] = mapped_column(String(50), default="N/A")
    max_target_height: Mapped[str] = mapped_column(String(50), default="N/A")
    # TacticalWeaponLink (TacticalLinkType: ID, Class, MappingType, ConfidenceLevel, ATT_1, ATT_2, StartDate)
    tact_weapon_link_id: Mapped[Optional[str]]         = mapped_column(String(50))
    tact_weapon_link_class: Mapped[Optional[str]]      = mapped_column(String(100))
    tact_weapon_link_mapping: Mapped[Optional[str]]    = mapped_column(String(50))
    tact_weapon_link_confidence: Mapped[Optional[str]] = mapped_column(String(20))
    tact_weapon_link_att1: Mapped[Optional[str]]       = mapped_column(String(100))
    tact_weapon_link_att2: Mapped[Optional[str]]       = mapped_column(String(100))
    tact_weapon_link_start_date: Mapped[Optional[str]] = mapped_column(String(50))

    tact_weapons: Mapped[List["TactWeapon"]] = relationship(
        "TactWeapon",
        primaryjoin="foreign(TactWeapon.tech_weapon_entity_id)==TechMissile.entity_id",
        back_populates="tech_missile", viewonly=True,
    )


class TechGun(Base):
    __tablename__ = "tech_gun"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    object_id: Mapped[Optional[str]] = mapped_column(String(255))
    reference_date: Mapped[Optional[str]] = mapped_column(String(50))
    modification_date: Mapped[Optional[str]] = mapped_column(String(50))
    state: Mapped[str]     = mapped_column(String(20), default="Unmodified")
    english_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[Optional[str]] = mapped_column(String(255))
    alias_json: Mapped[Optional[str]] = mapped_column(Text)
    introduction: Mapped[Optional[str]] = mapped_column(Text)
    comments: Mapped[Optional[str]] = mapped_column(String(1000))
    environment: Mapped[Optional[str]] = mapped_column(String(100))
    weapon_code: Mapped[str] = mapped_column(String(50), default="N/A")
    classification: Mapped[str] = mapped_column(String(255))
    manufacturer: Mapped[str] = mapped_column(String(255))
    source: Mapped[str]    = mapped_column(String(255))
    country: Mapped[Optional[str]] = mapped_column(String(255))
    weapon_function: Mapped[str] = mapped_column(String(255))
    caliber: Mapped[str]   = mapped_column(String(50), default="N/A")
    min_range: Mapped[str] = mapped_column(String(50), default="N/A")
    max_range: Mapped[str] = mapped_column(String(50), default="N/A")
    rate_of_fire: Mapped[str] = mapped_column(String(50), default="N/A")
    interval_between_salvos: Mapped[str] = mapped_column(String(50), default="N/A")
    max_salvo_duration: Mapped[str] = mapped_column(String(50), default="N/A")
    min_target_site: Mapped[str] = mapped_column(String(50), default="N/A")
    max_target_site: Mapped[str] = mapped_column(String(50), default="N/A")
    # TacticalWeaponLink (TacticalLinkType: ID, Class, MappingType, ConfidenceLevel, ATT_1, ATT_2, StartDate)
    tact_weapon_link_id: Mapped[Optional[str]]         = mapped_column(String(50))
    tact_weapon_link_class: Mapped[Optional[str]]      = mapped_column(String(100))
    tact_weapon_link_mapping: Mapped[Optional[str]]    = mapped_column(String(50))
    tact_weapon_link_confidence: Mapped[Optional[str]] = mapped_column(String(20))
    tact_weapon_link_att1: Mapped[Optional[str]]       = mapped_column(String(100))
    tact_weapon_link_att2: Mapped[Optional[str]]       = mapped_column(String(100))
    tact_weapon_link_start_date: Mapped[Optional[str]] = mapped_column(String(50))

    tact_weapons: Mapped[List["TactWeapon"]] = relationship(
        "TactWeapon",
        primaryjoin="foreign(TactWeapon.tech_weapon_entity_id)==TechGun.entity_id",
        back_populates="tech_gun", viewonly=True,
    )


class TechTransceiver(Base):
    __tablename__ = "tech_transceiver"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    object_id: Mapped[Optional[str]] = mapped_column(String(255))
    reference_date: Mapped[Optional[str]] = mapped_column(String(50))
    modification_date: Mapped[Optional[str]] = mapped_column(String(50))
    state: Mapped[str]     = mapped_column(String(20), default="Unmodified")
    english_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[Optional[str]] = mapped_column(String(255))
    alias_json: Mapped[Optional[str]] = mapped_column(Text)
    introduction: Mapped[Optional[str]] = mapped_column(Text)
    comments: Mapped[Optional[str]] = mapped_column(String(1000))
    environment: Mapped[Optional[str]] = mapped_column(String(100))
    classification: Mapped[str] = mapped_column(String(255))
    manufacturer: Mapped[str] = mapped_column(String(255))
    source: Mapped[str]    = mapped_column(String(255))
    country: Mapped[Optional[str]] = mapped_column(String(255))
    min_bandwidth: Mapped[str] = mapped_column(String(50), default="N/A")
    max_bandwidth: Mapped[str] = mapped_column(String(50), default="N/A")
    min_baud_rate: Mapped[str] = mapped_column(String(50), default="N/A")
    max_baud_rate: Mapped[str] = mapped_column(String(50), default="N/A")
    min_frequency: Mapped[str] = mapped_column(String(50), default="N/A")
    max_frequency: Mapped[str] = mapped_column(String(50), default="N/A")
    min_power: Mapped[str] = mapped_column(String(50), default="N/A")
    max_power: Mapped[str] = mapped_column(String(50), default="N/A")
    transmission_mode: Mapped[str] = mapped_column(String(255))
    modulation_analogue: Mapped[bool] = mapped_column(Boolean, default=False)
    modulation_digital: Mapped[bool]  = mapped_column(Boolean, default=False)
    # TacticalTransceiverLink (TacticalLinkType: ID, Class, MappingType, ConfidenceLevel, ATT_1, ATT_2, StartDate)
    tact_transceiver_link_id: Mapped[Optional[str]]         = mapped_column(String(50))
    tact_transceiver_link_class: Mapped[Optional[str]]      = mapped_column(String(100))
    tact_transceiver_link_mapping: Mapped[Optional[str]]    = mapped_column(String(50))
    tact_transceiver_link_confidence: Mapped[Optional[str]] = mapped_column(String(20))
    tact_transceiver_link_att1: Mapped[Optional[str]]       = mapped_column(String(100))
    tact_transceiver_link_att2: Mapped[Optional[str]]       = mapped_column(String(100))
    tact_transceiver_link_start_date: Mapped[Optional[str]] = mapped_column(String(50))

    tact_transceivers: Mapped[List["TactTransceiver"]] = relationship(
        "TactTransceiver",
        primaryjoin="foreign(TactTransceiver.tech_transceiver_entity_id)==TechTransceiver.entity_id",
        back_populates="tech_transceiver", viewonly=True,
    )


class TechLaser(Base):
    __tablename__ = "tech_laser"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    object_id: Mapped[Optional[str]] = mapped_column(String(255))
    reference_date: Mapped[Optional[str]] = mapped_column(String(50))
    modification_date: Mapped[Optional[str]] = mapped_column(String(50))
    state: Mapped[str]     = mapped_column(String(20), default="Unmodified")
    english_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[Optional[str]] = mapped_column(String(255))
    alias_json: Mapped[Optional[str]] = mapped_column(Text)
    introduction: Mapped[Optional[str]] = mapped_column(Text)
    comments: Mapped[Optional[str]] = mapped_column(String(1000))
    environment: Mapped[Optional[str]] = mapped_column(String(100))
    classification: Mapped[str] = mapped_column(String(255))
    manufacturer: Mapped[str] = mapped_column(String(255))
    source: Mapped[str]    = mapped_column(String(255))
    country: Mapped[Optional[str]] = mapped_column(String(255))
    function_code: Mapped[str] = mapped_column(String(255))
    laser_code: Mapped[str] = mapped_column(String(50), default="N/A")
    min_wavelength: Mapped[str] = mapped_column(String(50), default="N/A")
    max_wavelength: Mapped[str] = mapped_column(String(50), default="N/A")
    stability_deviation: Mapped[str] = mapped_column(String(50), default="N/A")
    stability_time: Mapped[str]      = mapped_column(String(50), default="N/A")
    clock_rate: Mapped[str]          = mapped_column(String(50), default="N/A")
    optronic_mode: Mapped[Optional[str]] = mapped_column(String(100))
    # TacticalLaserLink (TacticalLinkType: ID, Class, MappingType, ConfidenceLevel, ATT_1, ATT_2, StartDate)
    tact_laser_link_id: Mapped[Optional[str]]         = mapped_column(String(50))
    tact_laser_link_class: Mapped[Optional[str]]      = mapped_column(String(100))
    tact_laser_link_mapping: Mapped[Optional[str]]    = mapped_column(String(50))
    tact_laser_link_confidence: Mapped[Optional[str]] = mapped_column(String(20))
    tact_laser_link_att1: Mapped[Optional[str]]       = mapped_column(String(100))
    tact_laser_link_att2: Mapped[Optional[str]]       = mapped_column(String(100))
    tact_laser_link_start_date: Mapped[Optional[str]] = mapped_column(String(50))

    parameter_levels: Mapped[List["TechParameterLevel"]] = relationship(
        "TechParameterLevel", back_populates="laser", cascade="all, delete-orphan"
    )
    tact_lasers: Mapped[List["TactLaser"]] = relationship(
        "TactLaser",
        primaryjoin="foreign(TactLaser.tech_laser_entity_id)==TechLaser.entity_id",
        back_populates="tech_laser", viewonly=True,
    )


class TechParameterLevel(Base):
    """ParameterLevel element — child of tech:Laser (0..unbounded)."""
    __tablename__ = "tech_parameter_level"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    laser_id: Mapped[int]  = mapped_column(Integer, ForeignKey("tech_laser.id", ondelete="CASCADE"))
    entity_id: Mapped[str] = mapped_column(String(50))
    name: Mapped[str]      = mapped_column(String(255))
    source: Mapped[str]    = mapped_column(String(255))
    pri_agility: Mapped[str] = mapped_column(String(255))
    laser_type: Mapped[Optional[str]] = mapped_column(String(100))

    laser: Mapped["TechLaser"] = relationship("TechLaser", back_populates="parameter_levels")


class TechPassiveSensor(Base):
    __tablename__ = "tech_passive_sensor"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    object_id: Mapped[Optional[str]] = mapped_column(String(255))
    reference_date: Mapped[Optional[str]] = mapped_column(String(50))
    modification_date: Mapped[Optional[str]] = mapped_column(String(50))
    state: Mapped[str]     = mapped_column(String(20), default="Unmodified")
    english_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[Optional[str]] = mapped_column(String(255))
    alias_json: Mapped[Optional[str]] = mapped_column(Text)
    introduction: Mapped[Optional[str]] = mapped_column(Text)
    comments: Mapped[Optional[str]] = mapped_column(String(1000))
    environment: Mapped[Optional[str]] = mapped_column(String(100))
    classification: Mapped[str] = mapped_column(String(255))
    manufacturer: Mapped[str] = mapped_column(String(255))
    source: Mapped[str]    = mapped_column(String(255))
    country: Mapped[Optional[str]] = mapped_column(String(255))
    ir_band: Mapped[str]   = mapped_column(String(100))
    scan_type: Mapped[str] = mapped_column(String(100))
    threshold_contrast: Mapped[str] = mapped_column(String(100))
    technology: Mapped[str] = mapped_column(String(100))
    # TacticalSensorLink (TacticalLinkType: ID, Class, MappingType, ConfidenceLevel, ATT_1, ATT_2, StartDate)
    tact_sensor_link_id: Mapped[Optional[str]]         = mapped_column(String(50))
    tact_sensor_link_class: Mapped[Optional[str]]      = mapped_column(String(100))
    tact_sensor_link_mapping: Mapped[Optional[str]]    = mapped_column(String(50))
    tact_sensor_link_confidence: Mapped[Optional[str]] = mapped_column(String(20))
    tact_sensor_link_att1: Mapped[Optional[str]]       = mapped_column(String(100))
    tact_sensor_link_att2: Mapped[Optional[str]]       = mapped_column(String(100))
    tact_sensor_link_start_date: Mapped[Optional[str]] = mapped_column(String(50))

    tact_sensors: Mapped[List["TactPassiveSensor"]] = relationship(
        "TactPassiveSensor",
        primaryjoin="foreign(TactPassiveSensor.tech_passive_sensor_entity_id)==TechPassiveSensor.entity_id",
        back_populates="tech_passive_sensor", viewonly=True,
    )


class TechSensor(Base):
    __tablename__ = "tech_sensor"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    object_id: Mapped[Optional[str]] = mapped_column(String(255))
    reference_date: Mapped[Optional[str]] = mapped_column(String(50))
    modification_date: Mapped[Optional[str]] = mapped_column(String(50))
    state: Mapped[str]     = mapped_column(String(20), default="Unmodified")
    english_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[Optional[str]] = mapped_column(String(255))
    alias_json: Mapped[Optional[str]] = mapped_column(Text)
    introduction: Mapped[Optional[str]] = mapped_column(Text)
    comments: Mapped[Optional[str]] = mapped_column(String(1000))
    environment: Mapped[Optional[str]] = mapped_column(String(100))
    classification: Mapped[str] = mapped_column(String(255))
    manufacturer: Mapped[str] = mapped_column(String(255))
    source: Mapped[str]    = mapped_column(String(255))
    country: Mapped[Optional[str]] = mapped_column(String(255))
    sensor_type: Mapped[str] = mapped_column(String(100))
    freq_min: Mapped[Optional[str]] = mapped_column(String(50))
    freq_max: Mapped[Optional[str]] = mapped_column(String(50))
    sensitivity: Mapped[Optional[str]] = mapped_column(String(100))


class TechSeeker(Base):
    __tablename__ = "tech_seeker"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    object_id: Mapped[Optional[str]] = mapped_column(String(255))
    reference_date: Mapped[Optional[str]] = mapped_column(String(50))
    modification_date: Mapped[Optional[str]] = mapped_column(String(50))
    state: Mapped[str]     = mapped_column(String(20), default="Unmodified")
    english_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[Optional[str]] = mapped_column(String(255))
    alias_json: Mapped[Optional[str]] = mapped_column(Text)
    introduction: Mapped[Optional[str]] = mapped_column(Text)
    comments: Mapped[Optional[str]] = mapped_column(String(1000))
    environment: Mapped[Optional[str]] = mapped_column(String(100))
    classification: Mapped[str] = mapped_column(String(255))
    manufacturer: Mapped[str] = mapped_column(String(255))
    source: Mapped[str]    = mapped_column(String(255))
    country: Mapped[Optional[str]] = mapped_column(String(255))
    seeker_type: Mapped[str] = mapped_column(String(100))
    freq_min: Mapped[Optional[str]] = mapped_column(String(50))
    freq_max: Mapped[Optional[str]] = mapped_column(String(50))


# ---------------------------------------------------------------------------
# TACTICAL ENTITIES
# ---------------------------------------------------------------------------

class TactUnit(Base):
    __tablename__ = "tact_unit"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    object_id: Mapped[Optional[str]] = mapped_column(String(255))
    reference_date: Mapped[Optional[str]] = mapped_column(String(50))
    modification_date: Mapped[Optional[str]] = mapped_column(String(50))
    state: Mapped[str]     = mapped_column(String(20), default="Unmodified")
    english_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[Optional[str]] = mapped_column(String(255))
    comments: Mapped[Optional[str]] = mapped_column(String(1000))
    location_lat: Mapped[Optional[float]] = mapped_column(Float)
    location_lon: Mapped[Optional[float]] = mapped_column(Float)
    location_area: Mapped[Optional[str]]  = mapped_column(String(255))
    source: Mapped[str]    = mapped_column(String(255))
    country: Mapped[Optional[str]] = mapped_column(String(255))
    confidence_level: Mapped[Optional[str]] = mapped_column(String(20))
    classification: Mapped[Optional[str]]   = mapped_column(String(20))
    target_of_interest: Mapped[Optional[bool]] = mapped_column(Boolean)

    superior_unit_links: Mapped[List["TactUnitSuperiorLink"]] = relationship(
        "TactUnitSuperiorLink", back_populates="unit", cascade="all, delete-orphan"
    )
    installation_links: Mapped[List["TactUnitInstallationLink"]] = relationship(
        "TactUnitInstallationLink", back_populates="unit", cascade="all, delete-orphan"
    )
    platform_instances: Mapped[List["TactPlatformInstance"]] = relationship(
        "TactPlatformInstance", back_populates="parent_unit",
        foreign_keys="TactPlatformInstance.parent_unit_id",
    )


class TactUnitSuperiorLink(Base):
    """SuperiorUnit link (LinkUnitUnitType) — 0..unbounded on tact:Unit."""
    __tablename__ = "tact_unit_superior_link"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    unit_id: Mapped[int]   = mapped_column(Integer, ForeignKey("tact_unit.id", ondelete="CASCADE"))
    dest_class: Mapped[Optional[str]] = mapped_column(String(50))
    dest_id: Mapped[str]   = mapped_column(String(50))    # -> tact_unit.entity_id
    att_1: Mapped[Optional[str]] = mapped_column(String(100))
    att_2: Mapped[Optional[str]] = mapped_column(String(100))
    att_3: Mapped[Optional[str]] = mapped_column(String(100))
    start_date: Mapped[Optional[str]] = mapped_column(String(50))
    end_date: Mapped[Optional[str]]   = mapped_column(String(50))
    command_relationship: Mapped[Optional[str]] = mapped_column(String(100))
    task_group: Mapped[Optional[str]]           = mapped_column(String(100))
    operational_control: Mapped[Optional[str]]  = mapped_column(String(100))

    unit: Mapped["TactUnit"] = relationship("TactUnit", back_populates="superior_unit_links")


class TactUnitInstallationLink(Base):
    """InstallationLink on tact:Unit (LinkInstallationPlatformType) — 0..unbounded."""
    __tablename__ = "tact_unit_installation_link"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    unit_id: Mapped[int]   = mapped_column(Integer, ForeignKey("tact_unit.id", ondelete="CASCADE"))
    dest_class: Mapped[Optional[str]] = mapped_column(String(50))
    dest_id: Mapped[str]   = mapped_column(String(50))    # -> tact_installation.entity_id
    att_1: Mapped[Optional[str]] = mapped_column(String(100))
    att_2: Mapped[Optional[str]] = mapped_column(String(100))
    att_3: Mapped[Optional[str]] = mapped_column(String(100))
    start_date: Mapped[Optional[str]] = mapped_column(String(50))
    end_date: Mapped[Optional[str]]   = mapped_column(String(50))
    berth_location: Mapped[Optional[str]]   = mapped_column(String(255))
    assignment_date: Mapped[Optional[str]]  = mapped_column(String(50))

    unit: Mapped["TactUnit"] = relationship("TactUnit", back_populates="installation_links")


class TactInstallation(Base):
    __tablename__ = "tact_installation"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    object_id: Mapped[Optional[str]] = mapped_column(String(255))
    reference_date: Mapped[Optional[str]] = mapped_column(String(50))
    modification_date: Mapped[Optional[str]] = mapped_column(String(50))
    state: Mapped[str]     = mapped_column(String(20), default="Unmodified")
    english_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[Optional[str]] = mapped_column(String(255))
    comments: Mapped[Optional[str]] = mapped_column(String(1000))
    location_lat: Mapped[Optional[float]] = mapped_column(Float)
    location_lon: Mapped[Optional[float]] = mapped_column(Float)
    location_area: Mapped[Optional[str]]  = mapped_column(String(255))
    source: Mapped[str]    = mapped_column(String(255))
    country: Mapped[Optional[str]] = mapped_column(String(255))
    confidence_level: Mapped[Optional[str]] = mapped_column(String(20))
    classification: Mapped[Optional[str]]   = mapped_column(String(20))
    target_of_interest: Mapped[Optional[bool]] = mapped_column(Boolean)
    installation_type: Mapped[Optional[str]] = mapped_column(String(100))

    platform_instances: Mapped[List["TactPlatformInstance"]] = relationship(
        "TactPlatformInstance", back_populates="parent_installation",
        foreign_keys="TactPlatformInstance.parent_installation_id",
    )


class TactPlatformInstance(Base):
    __tablename__ = "tact_platform_instance"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    parent_unit_id: Mapped[Optional[int]]         = mapped_column(Integer, ForeignKey("tact_unit.id", ondelete="SET NULL"))
    parent_installation_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("tact_installation.id", ondelete="SET NULL"))

    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    object_id: Mapped[Optional[str]] = mapped_column(String(255))
    reference_date: Mapped[Optional[str]] = mapped_column(String(50))
    modification_date: Mapped[Optional[str]] = mapped_column(String(50))
    state: Mapped[str]     = mapped_column(String(20), default="Unmodified")
    english_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[Optional[str]] = mapped_column(String(255))
    comments: Mapped[Optional[str]] = mapped_column(String(1000))
    location_lat: Mapped[Optional[float]] = mapped_column(Float)
    location_lon: Mapped[Optional[float]] = mapped_column(Float)
    location_area: Mapped[Optional[str]]  = mapped_column(String(255))
    source: Mapped[str]    = mapped_column(String(255))
    country: Mapped[Optional[str]] = mapped_column(String(255))
    confidence_level: Mapped[Optional[str]] = mapped_column(String(20))
    classification: Mapped[Optional[str]]   = mapped_column(String(20))
    target_of_interest: Mapped[Optional[bool]] = mapped_column(Boolean)
    platform_type: Mapped[Optional[str]]  = mapped_column(String(100))
    callsign: Mapped[Optional[str]]       = mapped_column(String(100))
    platform_class_id: Mapped[str]           = mapped_column(String(50))  # raw <PlatformClassID> — REQUIRED by XSD
    # Cross-domain → Technical
    tech_platform_entity_id: Mapped[Optional[str]]          = mapped_column(String(50))
    tech_platform_instance_entity_id: Mapped[Optional[str]] = mapped_column(String(50))
    tech_link_mapping_type: Mapped[Optional[str]]   = mapped_column(String(50))
    tech_link_confidence: Mapped[Optional[str]]     = mapped_column(String(20))
    tech_link_att1: Mapped[Optional[str]]           = mapped_column(String(100))
    tech_link_att2: Mapped[Optional[str]]           = mapped_column(String(100))
    tech_link_start_date: Mapped[Optional[str]]     = mapped_column(String(50))

    parent_unit: Mapped[Optional["TactUnit"]] = relationship(
        "TactUnit", back_populates="platform_instances", foreign_keys=[parent_unit_id]
    )
    parent_installation: Mapped[Optional["TactInstallation"]] = relationship(
        "TactInstallation", back_populates="platform_instances", foreign_keys=[parent_installation_id]
    )
    tech_platform: Mapped[Optional["TechPlatform"]] = relationship(
        "TechPlatform",
        primaryjoin="foreign(TactPlatformInstance.tech_platform_entity_id)==TechPlatform.entity_id",
        back_populates="tact_instances", viewonly=True,
    )
    tech_platform_instance: Mapped[Optional["TechPlatformInstance"]] = relationship(
        "TechPlatformInstance",
        primaryjoin="foreign(TactPlatformInstance.tech_platform_instance_entity_id)==TechPlatformInstance.entity_id",
        back_populates="tact_instances", viewonly=True,
    )
    equipment_links: Mapped[List["TactEquipmentLink"]] = relationship(
        "TactEquipmentLink", back_populates="platform_instance", cascade="all, delete-orphan"
    )
    radar_instances: Mapped[List["TactRadarInstance"]] = relationship(
        "TactRadarInstance", back_populates="parent_platform",
        foreign_keys="TactRadarInstance.parent_platform_id",
    )
    weapons: Mapped[List["TactWeapon"]] = relationship(
        "TactWeapon", back_populates="parent_platform",
        foreign_keys="TactWeapon.parent_platform_id",
    )
    lasers: Mapped[List["TactLaser"]] = relationship(
        "TactLaser", back_populates="parent_platform",
        foreign_keys="TactLaser.parent_platform_id",
    )
    passive_sensors: Mapped[List["TactPassiveSensor"]] = relationship(
        "TactPassiveSensor", back_populates="parent_platform",
        foreign_keys="TactPassiveSensor.parent_platform_id",
    )
    transceivers: Mapped[List["TactTransceiver"]] = relationship(
        "TactTransceiver", back_populates="parent_platform",
        foreign_keys="TactTransceiver.parent_platform_id",
    )


class TactEquipmentLink(Base):
    """EquipmentLink on tact:PlatformInstance (LinkPlatformEquipmentType) — 0..unbounded."""
    __tablename__ = "tact_equipment_link"

    id: Mapped[int]               = mapped_column(Integer, primary_key=True, autoincrement=True)
    platform_instance_id: Mapped[int] = mapped_column(Integer, ForeignKey("tact_platform_instance.id", ondelete="CASCADE"))
    dest_class: Mapped[Optional[str]] = mapped_column(String(50))
    dest_id: Mapped[str]          = mapped_column(String(50))
    att_1: Mapped[Optional[str]]  = mapped_column(String(100))
    att_2: Mapped[Optional[str]]  = mapped_column(String(100))
    att_3: Mapped[Optional[str]]  = mapped_column(String(100))
    start_date: Mapped[Optional[str]] = mapped_column(String(50))
    end_date: Mapped[Optional[str]]   = mapped_column(String(50))
    quantity: Mapped[Optional[int]]            = mapped_column(Integer)
    mount_location: Mapped[Optional[str]]      = mapped_column(String(255))
    installation_date: Mapped[Optional[str]]   = mapped_column(String(50))
    status: Mapped[Optional[str]]              = mapped_column(String(50))

    platform_instance: Mapped["TactPlatformInstance"] = relationship(
        "TactPlatformInstance", back_populates="equipment_links"
    )


class TactRadarInstance(Base):
    __tablename__ = "tact_radar_instance"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    parent_platform_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("tact_platform_instance.id", ondelete="SET NULL"))

    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    object_id: Mapped[Optional[str]] = mapped_column(String(255))
    reference_date: Mapped[Optional[str]] = mapped_column(String(50))
    modification_date: Mapped[Optional[str]] = mapped_column(String(50))
    state: Mapped[str]     = mapped_column(String(20), default="Unmodified")
    english_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[Optional[str]] = mapped_column(String(255))
    comments: Mapped[Optional[str]] = mapped_column(String(1000))
    location_lat: Mapped[Optional[float]] = mapped_column(Float)
    location_lon: Mapped[Optional[float]] = mapped_column(Float)
    location_area: Mapped[Optional[str]]  = mapped_column(String(255))
    source: Mapped[str]    = mapped_column(String(255))
    country: Mapped[Optional[str]] = mapped_column(String(255))
    confidence_level: Mapped[Optional[str]] = mapped_column(String(20))
    classification: Mapped[Optional[str]]   = mapped_column(String(20))
    target_of_interest: Mapped[Optional[bool]] = mapped_column(Boolean)
    radar_class_id: Mapped[str]           = mapped_column(String(50))   # raw <RadarClassID> — REQUIRED by XSD
    # Cross-domain → Technical
    tech_radar_entity_id: Mapped[Optional[str]]          = mapped_column(String(50))
    tech_radar_instance_entity_id: Mapped[Optional[str]] = mapped_column(String(50))
    tech_link_mapping_type: Mapped[Optional[str]]  = mapped_column(String(50))
    tech_link_confidence: Mapped[Optional[str]]    = mapped_column(String(20))
    tech_link_att1: Mapped[Optional[str]]          = mapped_column(String(100))
    tech_link_att2: Mapped[Optional[str]]          = mapped_column(String(100))
    tech_link_start_date: Mapped[Optional[str]]    = mapped_column(String(50))

    parent_platform: Mapped[Optional["TactPlatformInstance"]] = relationship(
        "TactPlatformInstance", back_populates="radar_instances", foreign_keys=[parent_platform_id]
    )
    tech_radar: Mapped[Optional["TechRadar"]] = relationship(
        "TechRadar",
        primaryjoin="foreign(TactRadarInstance.tech_radar_entity_id)==TechRadar.entity_id",
        back_populates="tact_instances", viewonly=True,
    )
    tech_radar_instance: Mapped[Optional["TechRadarInstance"]] = relationship(
        "TechRadarInstance",
        primaryjoin="foreign(TactRadarInstance.tech_radar_instance_entity_id)==TechRadarInstance.entity_id",
        back_populates="tact_instances", viewonly=True,
    )
    contacts_links: Mapped[List["TactRadarContactsLink"]] = relationship(
        "TactRadarContactsLink", back_populates="radar_instance", cascade="all, delete-orphan"
    )


class TactRadarContactsLink(Base):
    """
    ContactsLink on tact:RadarInstance (LinkRadarContactsType) — 0..unbounded.
    Replaces old single-column approach — schema allows multiple contact links per radar instance.
    """
    __tablename__ = "tact_radar_contacts_link"

    id: Mapped[int]               = mapped_column(Integer, primary_key=True, autoincrement=True)
    radar_instance_id: Mapped[int] = mapped_column(Integer, ForeignKey("tact_radar_instance.id", ondelete="CASCADE"))
    dest_class: Mapped[Optional[str]] = mapped_column(String(50))
    dest_id: Mapped[str]          = mapped_column(String(50))    # -> entity being tracked
    att_1: Mapped[Optional[str]]  = mapped_column(String(100))
    att_2: Mapped[Optional[str]]  = mapped_column(String(100))
    att_3: Mapped[Optional[str]]  = mapped_column(String(100))
    start_date: Mapped[Optional[str]] = mapped_column(String(50))
    end_date: Mapped[Optional[str]]   = mapped_column(String(50))
    detection_range: Mapped[Optional[str]] = mapped_column(String(50))
    tracking_mode: Mapped[Optional[str]]   = mapped_column(String(50))
    update_rate: Mapped[Optional[str]]     = mapped_column(String(50))
    accuracy: Mapped[Optional[str]]        = mapped_column(String(100))

    radar_instance: Mapped["TactRadarInstance"] = relationship(
        "TactRadarInstance", back_populates="contacts_links"
    )


class TactOtherEquipment(Base):
    __tablename__ = "tact_other_equipment"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    parent_site_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("tact_equipment_site.id", ondelete="SET NULL"))
    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    object_id: Mapped[Optional[str]] = mapped_column(String(255))
    reference_date: Mapped[Optional[str]] = mapped_column(String(50))
    modification_date: Mapped[Optional[str]] = mapped_column(String(50))
    state: Mapped[str]     = mapped_column(String(20), default="Unmodified")
    english_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[Optional[str]] = mapped_column(String(255))
    comments: Mapped[Optional[str]] = mapped_column(String(1000))
    location_lat: Mapped[Optional[float]] = mapped_column(Float)
    location_lon: Mapped[Optional[float]] = mapped_column(Float)
    location_area: Mapped[Optional[str]]  = mapped_column(String(255))
    source: Mapped[str]    = mapped_column(String(255))
    country: Mapped[Optional[str]] = mapped_column(String(255))
    confidence_level: Mapped[Optional[str]] = mapped_column(String(20))
    classification: Mapped[Optional[str]]   = mapped_column(String(20))
    target_of_interest: Mapped[Optional[bool]] = mapped_column(Boolean)
    # TechnicalEquipmentLink (TechnicalLinkType: TechnicalID, TechnicalClass, MappingType, ConfidenceLevel, ATT_1, ATT_2, StartDate)
    tech_equipment_link_id: Mapped[Optional[str]]         = mapped_column(String(50))
    tech_equipment_link_class: Mapped[Optional[str]]      = mapped_column(String(100))
    tech_equipment_link_mapping: Mapped[Optional[str]]    = mapped_column(String(50))
    tech_equipment_link_confidence: Mapped[Optional[str]] = mapped_column(String(20))
    tech_equipment_link_att1: Mapped[Optional[str]]       = mapped_column(String(100))
    tech_equipment_link_att2: Mapped[Optional[str]]       = mapped_column(String(100))
    tech_equipment_link_start_date: Mapped[Optional[str]] = mapped_column(String(50))

    parent_site: Mapped[Optional["TactEquipmentSite"]] = relationship(
        "TactEquipmentSite", back_populates="other_equipment"
    )


class TactTransceiver(Base):
    __tablename__ = "tact_transceiver"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    parent_platform_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("tact_platform_instance.id", ondelete="SET NULL"))

    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    object_id: Mapped[Optional[str]] = mapped_column(String(255))
    reference_date: Mapped[Optional[str]] = mapped_column(String(50))
    modification_date: Mapped[Optional[str]] = mapped_column(String(50))
    state: Mapped[str]     = mapped_column(String(20), default="Unmodified")
    english_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[Optional[str]] = mapped_column(String(255))
    comments: Mapped[Optional[str]] = mapped_column(String(1000))
    location_lat: Mapped[Optional[float]] = mapped_column(Float)
    location_lon: Mapped[Optional[float]] = mapped_column(Float)
    location_area: Mapped[Optional[str]]  = mapped_column(String(255))
    source: Mapped[str]    = mapped_column(String(255))
    country: Mapped[Optional[str]] = mapped_column(String(255))
    confidence_level: Mapped[Optional[str]] = mapped_column(String(20))
    classification: Mapped[Optional[str]]   = mapped_column(String(20))
    target_of_interest: Mapped[Optional[bool]] = mapped_column(Boolean)
    tech_transceiver_entity_id: Mapped[Optional[str]] = mapped_column(String(50))
    tech_link_mapping_type: Mapped[Optional[str]] = mapped_column(String(50))
    tech_link_confidence: Mapped[Optional[str]]   = mapped_column(String(20))
    tech_link_att1: Mapped[Optional[str]]         = mapped_column(String(100))
    tech_link_att2: Mapped[Optional[str]]         = mapped_column(String(100))
    tech_link_start_date: Mapped[Optional[str]]   = mapped_column(String(50))

    comms_profile_links: Mapped[List["TactTransceiverCommsLink"]] = relationship(
        "TactTransceiverCommsLink", back_populates="transceiver", cascade="all, delete-orphan"
    )
    parent_platform: Mapped[Optional["TactPlatformInstance"]] = relationship(
        "TactPlatformInstance", back_populates="transceivers", foreign_keys=[parent_platform_id]
    )
    tech_transceiver: Mapped[Optional["TechTransceiver"]] = relationship(
        "TechTransceiver",
        primaryjoin="foreign(TactTransceiver.tech_transceiver_entity_id)==TechTransceiver.entity_id",
        back_populates="tact_transceivers", viewonly=True,
    )


class TactTransceiverCommsLink(Base):
    """CommsProfileLink on tact:Transceiver (LinkTransceiverCommsType) — 0..unbounded."""
    __tablename__ = "tact_transceiver_comms_link"

    id: Mapped[int]              = mapped_column(Integer, primary_key=True, autoincrement=True)
    transceiver_id: Mapped[int]  = mapped_column(Integer, ForeignKey("tact_transceiver.id", ondelete="CASCADE"))
    dest_class: Mapped[Optional[str]] = mapped_column(String(50))
    dest_id: Mapped[str]         = mapped_column(String(50))    # -> tact_comms_profile.entity_id
    att_1: Mapped[Optional[str]] = mapped_column(String(100))
    att_2: Mapped[Optional[str]] = mapped_column(String(100))
    att_3: Mapped[Optional[str]] = mapped_column(String(100))
    start_date: Mapped[Optional[str]] = mapped_column(String(50))
    end_date: Mapped[Optional[str]]   = mapped_column(String(50))
    frequency_band: Mapped[Optional[str]] = mapped_column(String(50))
    encryption: Mapped[Optional[str]]     = mapped_column(String(100))
    power_level: Mapped[Optional[str]]    = mapped_column(String(50))
    modulation_type: Mapped[Optional[str]] = mapped_column(String(100))

    transceiver: Mapped["TactTransceiver"] = relationship("TactTransceiver", back_populates="comms_profile_links")


class TactCommsProfile(Base):
    __tablename__ = "tact_comms_profile"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    object_id: Mapped[Optional[str]] = mapped_column(String(255))
    english_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[Optional[str]] = mapped_column(String(255))
    source: Mapped[str]    = mapped_column(String(255))  # fixed "Dyenah" in schema

    networks: Mapped[List["TactNetwork"]] = relationship(
        "TactNetwork", back_populates="comms_profile",
        foreign_keys="TactNetwork.parent_comms_id",
    )


class TactNetwork(Base):
    __tablename__ = "tact_network"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    parent_comms_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("tact_comms_profile.id", ondelete="SET NULL"))
    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    object_id: Mapped[Optional[str]] = mapped_column(String(255))
    english_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[Optional[str]] = mapped_column(String(255))
    source: Mapped[str]    = mapped_column(String(255))
    confidence_level: Mapped[Optional[str]] = mapped_column(String(20))
    comments: Mapped[Optional[str]] = mapped_column(String(1000))

    comms_profile: Mapped[Optional["TactCommsProfile"]] = relationship(
        "TactCommsProfile", back_populates="networks", foreign_keys=[parent_comms_id]
    )


class TactLaser(Base):
    __tablename__ = "tact_laser"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    parent_platform_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("tact_platform_instance.id", ondelete="SET NULL"))

    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    object_id: Mapped[Optional[str]] = mapped_column(String(255))
    reference_date: Mapped[Optional[str]] = mapped_column(String(50))
    modification_date: Mapped[Optional[str]] = mapped_column(String(50))
    state: Mapped[str]     = mapped_column(String(20), default="Unmodified")
    english_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[Optional[str]] = mapped_column(String(255))
    comments: Mapped[Optional[str]] = mapped_column(String(1000))
    location_lat: Mapped[Optional[float]] = mapped_column(Float)
    location_lon: Mapped[Optional[float]] = mapped_column(Float)
    location_area: Mapped[Optional[str]]  = mapped_column(String(255))
    source: Mapped[str]    = mapped_column(String(255))
    country: Mapped[Optional[str]] = mapped_column(String(255))
    confidence_level: Mapped[Optional[str]] = mapped_column(String(20))
    classification: Mapped[Optional[str]]   = mapped_column(String(20))
    target_of_interest: Mapped[Optional[bool]] = mapped_column(Boolean)
    laser_type: Mapped[Optional[str]]  = mapped_column(String(100))
    wavelength: Mapped[Optional[str]]  = mapped_column(String(100))
    tech_laser_entity_id: Mapped[Optional[str]] = mapped_column(String(50))
    tech_link_mapping_type: Mapped[Optional[str]] = mapped_column(String(50))
    tech_link_confidence: Mapped[Optional[str]]   = mapped_column(String(20))
    tech_link_att1: Mapped[Optional[str]]         = mapped_column(String(100))
    tech_link_att2: Mapped[Optional[str]]         = mapped_column(String(100))
    tech_link_start_date: Mapped[Optional[str]]   = mapped_column(String(50))

    parent_platform: Mapped[Optional["TactPlatformInstance"]] = relationship(
        "TactPlatformInstance", back_populates="lasers", foreign_keys=[parent_platform_id]
    )
    tech_laser: Mapped[Optional["TechLaser"]] = relationship(
        "TechLaser",
        primaryjoin="foreign(TactLaser.tech_laser_entity_id)==TechLaser.entity_id",
        back_populates="tact_lasers", viewonly=True,
    )


class TactPassiveSensor(Base):
    __tablename__ = "tact_passive_sensor"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    parent_platform_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("tact_platform_instance.id", ondelete="SET NULL"))

    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    object_id: Mapped[Optional[str]] = mapped_column(String(255))
    reference_date: Mapped[Optional[str]] = mapped_column(String(50))
    modification_date: Mapped[Optional[str]] = mapped_column(String(50))
    state: Mapped[str]     = mapped_column(String(20), default="Unmodified")
    english_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[Optional[str]] = mapped_column(String(255))
    comments: Mapped[Optional[str]] = mapped_column(String(1000))
    location_lat: Mapped[Optional[float]] = mapped_column(Float)
    location_lon: Mapped[Optional[float]] = mapped_column(Float)
    location_area: Mapped[Optional[str]]  = mapped_column(String(255))
    source: Mapped[str]    = mapped_column(String(255))
    country: Mapped[Optional[str]] = mapped_column(String(255))
    confidence_level: Mapped[Optional[str]] = mapped_column(String(20))
    classification: Mapped[Optional[str]]   = mapped_column(String(20))
    target_of_interest: Mapped[Optional[bool]] = mapped_column(Boolean)
    sensor_type: Mapped[Optional[str]] = mapped_column(String(100))
    band: Mapped[Optional[str]]        = mapped_column(String(100))
    tech_passive_sensor_entity_id: Mapped[Optional[str]] = mapped_column(String(50))
    tech_link_mapping_type: Mapped[Optional[str]] = mapped_column(String(50))
    tech_link_confidence: Mapped[Optional[str]]   = mapped_column(String(20))
    tech_link_att1: Mapped[Optional[str]]         = mapped_column(String(100))
    tech_link_att2: Mapped[Optional[str]]         = mapped_column(String(100))
    tech_link_start_date: Mapped[Optional[str]]   = mapped_column(String(50))

    parent_platform: Mapped[Optional["TactPlatformInstance"]] = relationship(
        "TactPlatformInstance", back_populates="passive_sensors", foreign_keys=[parent_platform_id]
    )
    tech_passive_sensor: Mapped[Optional["TechPassiveSensor"]] = relationship(
        "TechPassiveSensor",
        primaryjoin="foreign(TactPassiveSensor.tech_passive_sensor_entity_id)==TechPassiveSensor.entity_id",
        back_populates="tact_sensors", viewonly=True,
    )


class TactWeapon(Base):
    __tablename__ = "tact_weapon"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    parent_platform_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("tact_platform_instance.id", ondelete="SET NULL"))

    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    object_id: Mapped[Optional[str]] = mapped_column(String(255))
    reference_date: Mapped[Optional[str]] = mapped_column(String(50))
    modification_date: Mapped[Optional[str]] = mapped_column(String(50))
    state: Mapped[str]     = mapped_column(String(20), default="Unmodified")
    english_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[Optional[str]] = mapped_column(String(255))
    comments: Mapped[Optional[str]] = mapped_column(String(1000))
    location_lat: Mapped[Optional[float]] = mapped_column(Float)
    location_lon: Mapped[Optional[float]] = mapped_column(Float)
    location_area: Mapped[Optional[str]]  = mapped_column(String(255))
    source: Mapped[str]    = mapped_column(String(255))
    country: Mapped[Optional[str]] = mapped_column(String(255))
    confidence_level: Mapped[Optional[str]] = mapped_column(String(20))
    classification: Mapped[Optional[str]]   = mapped_column(String(20))
    target_of_interest: Mapped[Optional[bool]] = mapped_column(Boolean)
    weapon_type: Mapped[str] = mapped_column(String(100))
    caliber: Mapped[Optional[str]] = mapped_column(String(50))
    range_val: Mapped[Optional[str]] = mapped_column(String(50))
    tech_weapon_entity_id: Mapped[Optional[str]] = mapped_column(String(50))
    tech_weapon_class: Mapped[Optional[str]]     = mapped_column(String(50))  # 'Missile'|'Gun'|'WeaponSystem'
    tech_link_mapping_type: Mapped[Optional[str]] = mapped_column(String(50))
    tech_link_confidence: Mapped[Optional[str]]   = mapped_column(String(20))
    tech_link_att1: Mapped[Optional[str]]         = mapped_column(String(100))
    tech_link_att2: Mapped[Optional[str]]         = mapped_column(String(100))
    tech_link_start_date: Mapped[Optional[str]]   = mapped_column(String(50))

    parent_platform: Mapped[Optional["TactPlatformInstance"]] = relationship(
        "TactPlatformInstance", back_populates="weapons", foreign_keys=[parent_platform_id]
    )
    tech_weapon_system: Mapped[Optional["TechWeaponSystem"]] = relationship(
        "TechWeaponSystem",
        primaryjoin="foreign(TactWeapon.tech_weapon_entity_id)==TechWeaponSystem.entity_id",
        back_populates="tact_weapons", viewonly=True,
    )
    tech_missile: Mapped[Optional["TechMissile"]] = relationship(
        "TechMissile",
        primaryjoin="foreign(TactWeapon.tech_weapon_entity_id)==TechMissile.entity_id",
        back_populates="tact_weapons", viewonly=True,
    )
    tech_gun: Mapped[Optional["TechGun"]] = relationship(
        "TechGun",
        primaryjoin="foreign(TactWeapon.tech_weapon_entity_id)==TechGun.entity_id",
        back_populates="tact_weapons", viewonly=True,
    )


class TactContacts2D(Base):
    __tablename__ = "tact_contacts_2d"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    contact_entity_id: Mapped[str] = mapped_column(String(50))  # -> tact_platform_instance.entity_id
    radar_instance_id: Mapped[str] = mapped_column(String(50))  # -> tact_radar_instance.entity_id
    contact_time: Mapped[str] = mapped_column(String(50))
    azimuth: Mapped[float]    = mapped_column(Float)
    range_val: Mapped[float]  = mapped_column(Float)

    detected_platform: Mapped[Optional["TactPlatformInstance"]] = relationship(
        "TactPlatformInstance",
        primaryjoin="foreign(TactContacts2D.contact_entity_id)==TactPlatformInstance.entity_id",
        viewonly=True,
    )
    radar_instance: Mapped[Optional["TactRadarInstance"]] = relationship(
        "TactRadarInstance",
        primaryjoin="foreign(TactContacts2D.radar_instance_id)==TactRadarInstance.entity_id",
        viewonly=True,
    )


class TactHistoricalLocation(Base):
    __tablename__ = "tact_historical_location"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    ref_entity_id: Mapped[str] = mapped_column(String(50))   # -> any tactical entity
    start_date: Mapped[str]  = mapped_column(String(50))
    end_date: Mapped[Optional[str]] = mapped_column(String(50))
    location_lat: Mapped[Optional[float]] = mapped_column(Float)
    location_lon: Mapped[Optional[float]] = mapped_column(Float)
    location_area: Mapped[Optional[str]]  = mapped_column(String(255))
    source: Mapped[Optional[str]] = mapped_column(String(255))


class TactRadarInterception(Base):
    __tablename__ = "tact_radar_interception"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    radar_instance_id: Mapped[str] = mapped_column(String(50))  # -> tact_radar_instance.entity_id
    interception_time: Mapped[str] = mapped_column(String(50))
    frequency: Mapped[Optional[float]] = mapped_column(Float)
    pri: Mapped[Optional[str]]         = mapped_column(String(50))
    pulse_width: Mapped[Optional[float]] = mapped_column(Float)  # MicrosecondsType (xs:double)
    location_lat: Mapped[Optional[float]] = mapped_column(Float)
    location_lon: Mapped[Optional[float]] = mapped_column(Float)
    location_area: Mapped[Optional[str]]  = mapped_column(String(255))


class TactEquipmentSite(Base):
    __tablename__ = "tact_equipment_site"

    id: Mapped[int]        = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("upload_log.id", ondelete="SET NULL"), nullable=True)
    entity_id: Mapped[str] = mapped_column(String(50), unique=True)
    object_id: Mapped[Optional[str]] = mapped_column(String(255))
    reference_date: Mapped[Optional[str]] = mapped_column(String(50))
    modification_date: Mapped[Optional[str]] = mapped_column(String(50))
    state: Mapped[str]     = mapped_column(String(20), default="Unmodified")
    english_name: Mapped[str] = mapped_column(String(255))
    name: Mapped[Optional[str]] = mapped_column(String(255))
    comments: Mapped[Optional[str]] = mapped_column(String(1000))
    location_lat: Mapped[Optional[float]] = mapped_column(Float)
    location_lon: Mapped[Optional[float]] = mapped_column(Float)
    location_area: Mapped[Optional[str]]  = mapped_column(String(255))
    source: Mapped[str]    = mapped_column(String(255))
    country: Mapped[Optional[str]] = mapped_column(String(255))
    confidence_level: Mapped[Optional[str]] = mapped_column(String(20))
    classification: Mapped[Optional[str]]   = mapped_column(String(20))
    target_of_interest: Mapped[Optional[bool]] = mapped_column(Boolean)
    site_type: Mapped[str] = mapped_column(String(100))

    other_equipment: Mapped[List["TactOtherEquipment"]] = relationship(
        "TactOtherEquipment", back_populates="parent_site",
        foreign_keys="TactOtherEquipment.parent_site_id",
    )
